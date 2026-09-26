#!/usr/bin/env python3
"""Bridge Git/Claude Cloud V1.2. Python 3.10+, biblioth�que standard uniquement."""
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import time


class BridgeError(Exception):
    pass


class Paused(BridgeError):
    pass


def read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as exc:
        raise BridgeError(f"JSON illisible : {path}: {exc}") from exc


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def file_digest(path):
    data = path.read_bytes()
    if path.suffix.lower() in (".md", ".json"):
        data = data.decode("utf-8-sig").replace("\r\n", "\n").encode("utf-8")
    return hashlib.sha256(data).hexdigest()


def safe_path(root, value, prefix=None):
    if not isinstance(value, str) or not value or "\\" in value or ":" in value:
        raise BridgeError(f"Chemin invalide : {value!r}")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or path.as_posix() != value:
        raise BridgeError(f"Chemin invalide : {value!r}")
    if prefix and not value.startswith(prefix + "/"):
        raise BridgeError(f"Chemin hors du dossier {prefix} : {value}")
    root = Path(root).resolve()
    result = root.joinpath(*path.parts)
    if not result.resolve().is_relative_to(root):
        raise BridgeError(f"Chemin hors d�p�t : {value}")
    current = result
    while current != root:
        if current.is_symlink() or (hasattr(current, "is_junction") and current.is_junction()):
            raise BridgeError(f"Lien de fichiers interdit : {value}")
        current = current.parent
    return result


def guard(root):
    if (root / "automation/STOP").exists():
        raise Paused("STOP pr�sent : aucune nouvelle action.")
    control = read_json(root / "automation/control.json")
    if not isinstance(control, dict) or any(type(control.get(k)) is not bool for k in ("paused", "emergency_stop")):
        raise BridgeError("control.json doit contenir paused et emergency_stop bool�ens.")
    if control["paused"] or control["emergency_stop"]:
        raise Paused("Pipeline en pause / arr�t d'urgence.")


@contextlib.contextmanager
def lock(root):
    path = root / "automation/.local/bridge.lock"
    path.parent.mkdir(parents=True, exist_ok=True)
    # Verrou OS lib�r� m�me en cas de crash. Le fichier peut rester en place.
    with path.open("a+b") as stream:
        try:
            if path.stat().st_size == 0:
                stream.write(b"0")
                stream.flush()
            stream.seek(0)
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            raise BridgeError("Un autre bridge travaille d�j� dans ce dossier.") from exc
        try:
            yield
        finally:
            stream.seek(0)
            if os.name == "nt":
                msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(stream, fcntl.LOCK_UN)


def validate_task(root, task):
    if not isinstance(task, dict) or not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,79}", task.get("id", "")):
        raise BridgeError("Identifiant de t�che invalide.")
    for key in ("iteration", "max_iterations"):
        if type(task.get(key)) is not int or task[key] < 0:
            raise BridgeError(f"{key} doit �tre un entier positif ou nul.")
    if task["iteration"] > task["max_iterations"]:
        raise BridgeError("It�ration au-del� de max_iterations.")
    if not safe_path(root, task.get("brief_source"), "docs").is_file():
        raise BridgeError("Brief manquant.")
    shots = task.get("screenshots")
    if not isinstance(shots, list) or not shots or len(set(shots)) != len(shots):
        raise BridgeError("Liste de captures vide ou avec doublons.")
    current = []
    prefix = f"automation/screenshots/{task['id']}"
    iteration = f"iteration_{task['iteration']:02d}_"
    for shot in shots:
        path = safe_path(root, shot, prefix)
        if path.name.startswith(iteration):
            if not path.is_file() or path.suffix.lower() != ".png" or path.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
                raise BridgeError(f"Capture PNG manquante/invalide : {shot}")
            current.append(shot)
    for required in ("main", "compare"):
        if f"{prefix}/{iteration}{required}.png" not in current:
            raise BridgeError(f"Capture {required} absente de l'it�ration courante.")
    return sorted(current)


def make_request(root, task):
    shots = validate_task(root, task)
    files = [task["brief_source"], "CLAUDE.md", "docs/ART_DIRECTION.md", "docs/VISUAL_QA.md",
             "docs/MONSTER_PRODUCTION.md", "automation/review.schema.json", *shots]
    # Les moodboards et autres r�f�rences versionn�es doivent aussi �tre identifiables.
    refs = root / "docs/references"
    if refs.exists():
        files += [p.relative_to(root).as_posix() for p in sorted(refs.rglob("*")) if p.is_file()]
    hashes = {}
    for rel in sorted(set(files)):
        path = safe_path(root, rel)
        if not path.is_file():
            raise BridgeError(f"Document requis absent : {rel}")
        hashes[rel] = file_digest(path)
    # Exclure statut/latest_review/notes : appliquer une review ne doit pas invalider sa demande.
    brief = {k: v for k, v in task.items() if k not in ("status", "latest_review", "notes", "screenshots")}
    data = {"schema_version": 1, "task_id": task["id"], "iteration": task["iteration"],
            "task": brief, "screenshots": shots, "sha256": hashes}
    digest = hashlib.sha256(json.dumps(data, sort_keys=True, ensure_ascii=False).encode("utf-8")).hexdigest()
    data["request_id"] = digest
    return data


def validate_review(review, request):
    required = {"request_id", "task_id", "iteration", "verdict", "summary", "visible_issues",
                "required_changes", "references_checked", "confidence"}
    if not isinstance(review, dict) or not required <= review.keys() or set(review) - required - {"human_attention"}:
        raise BridgeError("Review incompl�te ou champs inconnus.")
    for key in ("request_id", "task_id", "iteration"):
        if type(review[key]) is not type(request[key]) or review[key] != request[key]:
            raise BridgeError(f"Review p�rim�e / mauvaise t�che : {key} ne correspond pas.")
    if review["verdict"] not in ("PASS", "FIX") or review["confidence"] not in ("low", "medium", "high"):
        raise BridgeError("Verdict ou confiance invalide.")
    if not isinstance(review["summary"], str) or not review["summary"].strip():
        raise BridgeError("R�sum� vide.")
    for key in ("visible_issues", "required_changes", "references_checked", "human_attention"):
        values = review.get(key, [])
        if not isinstance(values, list) or any(not isinstance(v, str) or not v.strip() for v in values):
            raise BridgeError(f"Liste invalide : {key}.")
    if review["verdict"] == "FIX" and (not review["visible_issues"] or not review["required_changes"]):
        raise BridgeError("FIX sans probl�me visible et correction concr�te.")
    if review["verdict"] == "PASS" and (review["visible_issues"] or review["required_changes"]):
        raise BridgeError("PASS contradictoire avec des d�fauts/corrections restants.")
    if not review["references_checked"]:
        raise BridgeError("Aucune r�f�rence r�ellement inspect�e indiqu�e.")
    return review


class Bridge:
    def __init__(self, root, config):
        self.root = Path(root).resolve()
        self.config = config
        self.remote = config.get("remote", "origin")
        self.branch = config.get("branch", "feature/monster-pipeline")
        self.review_branch = config.get("review_branch", "")

    def run(self, args, *, check=True, input_text=None, timeout=60):
        guard(self.root)
        env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="Never")
        try:
            result = subprocess.run(args, cwd=self.root, env=env, input=input_text,
                                    capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise BridgeError(f"Commande indisponible ou d�lai d�pass� : {args[0]}") from exc
        if check and result.returncode:
            raise BridgeError(f"�chec {args[0]} : {(result.stderr or result.stdout).strip()[:1500]}")
        return result

    def git(self, *args, **kwargs):
        return self.run(["git", *args], **kwargs)

    def check_config(self, online=False):
        if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]*", self.remote):
            raise BridgeError("Nom de remote invalide.")
        for branch in (self.branch, self.review_branch):
            if not branch or branch.startswith("-") or self.git("check-ref-format", "--branch", branch, check=False).returncode:
                raise BridgeError("Configurer branch et review_branch avec des noms de branches valides.")
        if self.branch in ("main", "master", "develop") or self.review_branch in ("main", "master", "develop", self.branch):
            raise BridgeError("La branche du manager doit �tre distincte et les branches principales sont prot�g�es.")
        if self.git("branch", "--show-current").stdout.strip() != self.branch:
            raise BridgeError(f"Lancer le bridge dans le checkout de {self.branch}.")
        for key, default in (("poll_seconds", 15), ("review_timeout_minutes", 45)):
            value = self.config.get(key, default)
            if type(value) not in (int, float) or not 1 <= value <= 3600:
                raise BridgeError(f"{key} doit �tre un nombre entre 1 et 3600.")
        if online:
            session = self.config.get("session_id", "")
            if not re.fullmatch(r"(?:session|cse)_[a-zA-Z0-9_-]+", session):
                raise BridgeError("Configurer session_id avec l'identifiant r�el du Manager Cloud.")
            exe = self.config.get("claude_command", "claude")
            if not isinstance(exe, str) or not shutil.which(exe):
                raise BridgeError("Claude CLI introuvable. Configurer claude_command dans le fichier local.")

    def publish(self, paths, message):
        # Ne jamais embarquer des fichiers ajout�s par quelqu'un d'autre.
        if self.git("diff", "--cached", "--name-only").stdout.strip():
            raise BridgeError("Index Git non vide. Terminer le commit existant avant le bridge.")
        paths = sorted(set(paths))
        for rel in paths:
            safe_path(self.root, rel, "automation")
        self.git("add", "--", *paths)
        if self.git("diff", "--cached", "--name-only").stdout.strip():
            self.git("commit", "-m", message)
        # Aucun force, reset, checkout, merge ou stash automatique.
        self.git("push", self.remote, f"HEAD:refs/heads/{self.branch}")
        return self.git("rev-parse", "HEAD").stdout.strip()

    def fetch_review(self, rel):
        remote_ref = f"refs/heads/{self.review_branch}"
        result = self.git("ls-remote", "--heads", self.remote, remote_ref)
        if not result.stdout.strip():
            return None
        self.git("fetch", "--no-tags", self.remote, remote_ref)
        sha = self.git("rev-parse", "FETCH_HEAD").stdout.strip()
        result = self.git("show", f"{sha}:{rel}", check=False)
        if result.returncode:
            return None
        try:
            return json.loads(result.stdout)
        except ValueError as exc:
            raise BridgeError("La review distante n'est pas un JSON valide.") from exc

    def send(self, request, rel, source_commit, receipt_path, resend=False):
        receipt = read_json(receipt_path) if receipt_path.exists() else {}
        if receipt and not resend:
            print("Demande d�j� envoy�e ou livraison incertaine : attente, sans nouvel envoi.")
            return
        prompt = ("Lis automation/prompts/manager_cloud_bootstrap.md. "
                  f"Review {request['request_id']}. D�p�t : {self.git('remote', 'get-url', self.remote).stdout.strip()}. "
                  f"Source : {self.branch}, commit {source_commit}, manifeste {rel}. "
                  f"Publie uniquement la review demand�e sur ta branche {self.review_branch}. "
                  "V�rifie les SHA256 du manifeste et ouvre r�ellement les PNG. "
                  "Ne modifie ni la DA, ni les t�ches, ni les assets. "
                  "Si cette request_id est d�j� trait�e, r�utilise sa review. Pas de PASS sans inspection visuelle.")
        write_json(receipt_path, {"request_id": request["request_id"], "status": "delivery_unknown", "source_commit": source_commit})
        result = self.run([self.config.get("claude_command", "claude"), "-p", "--cloud", self.config["session_id"],
                           "--output-format", "json"], input_text=prompt, timeout=60)
        try:
            response = json.loads(result.stdout)
        except ValueError as exc:
            raise BridgeError("Envoi Cloud incertain : v�rifier la session avant --resend.") from exc
        if not isinstance(response, dict) or response.get("ok") is not True:
            raise BridgeError("Cloud n'a pas confirm� l'envoi. V�rifier la session avant --resend.")
        write_json(receipt_path, {"request_id": request["request_id"], "status": "sent", "source_commit": source_commit})

    def apply(self, task_id, request, review, rel):
        guard(self.root)
        queue = read_json(self.root / "automation/tasks.json")
        task = next(t for t in queue["queue"] if t["id"] == task_id)
        if make_request(self.root, task) != request or task["status"] != "awaiting_review":
            raise BridgeError("La t�che ou ses entr�es ont chang� pendant la review. Rien n'est appliqu�.")
        validate_review(review, request)
        if review.get("human_attention") or review["confidence"] == "low":
            status = "human_review"
        elif review["verdict"] == "PASS":
            status = "done"
        else:
            status = "human_review" if task["iteration"] >= task["max_iterations"] else "fix_required"
        state_path = self.root / f"automation/state/{task_id}.json"
        state = read_json(state_path)
        # �crire la review, puis l'�tat, et la queue en dernier. Une interruption reste rejouable.
        write_json(safe_path(self.root, rel, "automation/reviews"), review)
        state.update(status=status, stage="review", latest_review=rel,
                     last_completed_step="cloud_review_received",
                     next_step={"done": "next_task", "fix_required": "apply_required_changes", "human_review": "wait_for_human"}[status])
        write_json(state_path, state)
        task.update(status=status, latest_review=rel)
        write_json(self.root / "automation/tasks.json", queue)
        print(f"{task_id}: {review['verdict']} -> {status}. Review : {rel}")

    def process(self, task_id=None, resend=False, check_only=False):
        guard(self.root)
        queue = read_json(self.root / "automation/tasks.json")
        if not isinstance(queue, dict) or not isinstance(queue.get("queue"), list):
            raise BridgeError("tasks.json doit contenir une queue.")
        ids = [t.get("id") for t in queue["queue"]]
        if len(ids) != len(set(ids)):
            raise BridgeError("Identifiants de t�ches en double.")
        waiting = [t for t in queue["queue"] if t.get("status") == "awaiting_review" and (not task_id or t.get("id") == task_id)]
        if len(waiting) != 1:
            raise BridgeError("Il faut exactement une t�che awaiting_review (ou s�lectionner --task).")
        task = waiting[0]
        request = make_request(self.root, task)
        state = read_json(self.root / f"automation/state/{task['id']}.json")
        if state.get("task_id") != task["id"] or state.get("iteration") != task["iteration"]:
            raise BridgeError("�tat incoh�rent avec la t�che.")
        if check_only:
            print(f"Entr�es valides : {task['id']}, it�ration {task['iteration']}, {len(request['screenshots'])} captures.")
            self.check_config(online=True)
            print("Configuration locale pr�te. Authentification et Cloud non test�s par --check.")
            return
        self.check_config(online=True)
        rid = request["request_id"]
        req_rel = f"automation/requests/{task['id']}_iteration_{task['iteration']:02d}_{rid}.json"
        rev_rel = f"automation/reviews/{task['id']}_iteration_{task['iteration']:02d}_{rid}.json"
        # V�rifier les entr�es artistiques d�j� commit�es, sans les publier automatiquement.
        for rel in request["sha256"]:
            if rel not in request["screenshots"]:
                committed = self.git("rev-parse", f"HEAD:{rel}").stdout.strip()
                current = self.git("hash-object", f"--path={rel}", rel).stdout.strip()
                if current != committed:
                    raise BridgeError(f"Document modifi� non commit� : {rel}")
        write_json(self.root / req_rel, request)
        paths = ["automation/tasks.json", f"automation/state/{task['id']}.json", req_rel, *request["screenshots"]]
        source = self.publish(paths, f"chore(automation): demande QA {task['id']} passe {task['iteration']}")
        # Contr�ler la review AVANT l'envoi, y compris apr�s un red�marrage du PC.
        review = self.fetch_review(rev_rel)
        if review is None:
            self.send(request, req_rel, source, self.root / f"automation/.local/{rid}.json", resend=resend)
        deadline = time.monotonic() + 60 * self.config.get("review_timeout_minutes", 45)
        while review is None:
            guard(self.root)
            if time.monotonic() >= deadline:
                raise BridgeError("D�lai de review atteint. T�che conserv�e awaiting_review ; relancer plus tard.")
            until = min(deadline, time.monotonic() + self.config.get("poll_seconds", 15))
            while time.monotonic() < until:
                guard(self.root)
                time.sleep(min(1, max(0, until - time.monotonic())))
            review = self.fetch_review(rev_rel)
        self.apply(task["id"], request, review, rev_rel)
        print("R�sultat sauvegard� localement. Le worker reprend ; aucun clic dans Claude Windows n'est simul�.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task")
    parser.add_argument("--check", action="store_true", help="Valide sans envoi, commit ou push.")
    parser.add_argument("--resend", action="store_true", help="R�envoi explicite apr�s contr�le de la session Cloud.")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    try:
        config = read_json(root / "automation/cloud_manager_config.json")
        local = root / "automation/cloud_manager_config.local.json"
        if local.exists():
            config.update(read_json(local))
        bridge = Bridge(root, config)
        if args.check:
            bridge.process(args.task, check_only=True)
        else:
            with lock(root):
                bridge.process(args.task, resend=args.resend)
        return 0
    except Paused as exc:
        print(str(exc), file=sys.stderr)
        return 3
    except (BridgeError, OSError, ValueError, KeyError, TypeError, StopIteration) as exc:
        print(f"Bridge arr�t� : {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("Arr�t demand�. �tat conserv� ; relancer pour reprendre.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
