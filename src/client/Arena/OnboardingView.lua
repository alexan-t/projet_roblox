--!strict
-- Vue d'accueil d'un nouveau joueur (pur, testé par tools/test-presentation.ps1) — docs/QUESTS.md.
-- Au premier spawn d'une session d'onboarding, la caméra se place derrière le personnage, légèrement
-- au-dessus, et regarde vers l'arène de SON plot : le joueur voit son chemin, son portail, son arène.
-- Aucune API Roblox : OnboardingCameraController fournit les positions (Vector3 ou équivalent).

local OnboardingView = {}

OnboardingView.Back = 13 -- studs derrière le personnage
OnboardingView.Up = 6 -- studs au-dessus de ses pieds (racine + Up)
OnboardingView.LookAhead = 18 -- studs devant lui, vers l'arène : point regardé
OnboardingView.LookUp = 1 -- point regardé un peu au-dessus du sol
OnboardingView.Duration = 0.6 -- s de mise en place (0,4 à 0,8 s), puis caméra rendue au joueur

export type View = { Onboarding: boolean?, Completed: boolean? }

-- Joue-t-on la mise en place ? Une seule fois par session, et seulement pendant la quête d'accueil
-- (Onboarding) pas encore terminée. Jamais après un reset / une mort (déjà jouée), jamais pour un
-- profil sorti du tutoriel (quête suivante, ou plus de quête).
function OnboardingView.shouldPlay(view: View?, alreadyPlayed: boolean): boolean
	return not alreadyPlayed and view ~= nil and view.Onboarding == true and view.Completed ~= true
end

-- Direction horizontale (unitaire) du personnage vers la cible ; nil si la cible est confondue.
function OnboardingView.facing(root: Vector3, target: Vector3): Vector3?
	local flat = Vector3.new(target.X - root.X, 0, target.Z - root.Z)
	if flat.Magnitude < 0.5 then
		return nil
	end
	return flat.Unit
end

-- Œil de la caméra et point regardé : derrière / au-dessus du personnage, vers la cible.
function OnboardingView.frame(root: Vector3, direction: Vector3): (Vector3, Vector3)
	local eye = root - direction * OnboardingView.Back + Vector3.new(0, OnboardingView.Up, 0)
	local look = root + direction * OnboardingView.LookAhead + Vector3.new(0, OnboardingView.LookUp, 0)
	return eye, look
end

return OnboardingView
