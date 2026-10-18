--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Règles de présentation du panneau Quêtes (Shared.Quests.QuestLog) : tools/test-ui.ps1.

return function(QuestLog: any)
	local passed, failed = 0, 0
	local function test(name: string, run: () -> ())
		local ok, err = pcall(run)
		if ok then
			passed += 1
			print("PASS " .. name)
		else
			failed += 1
			print("FAIL " .. name .. ": " .. tostring(err))
		end
	end

	local function q(id: string, progress: number, target: number, claimed: boolean?, auto: boolean?): any
		return { Id = id, Progress = progress, Target = target, Completed = progress >= target, Claimed = claimed == true, AutoClaim = auto == true }
	end

	test("state: in progress, claimable, claimed; an AutoClaim quest is never 'to claim'", function()
		assert(QuestLog.state(q("A", 0, 1)) == "InProgress")
		assert(QuestLog.state(q("A", 2, 5)) == "InProgress")
		assert(QuestLog.state(q("A", 1, 1)) == "Claimable")
		assert(QuestLog.state(q("A", 1, 1, true)) == "Claimed")
		assert(QuestLog.state(q("A", 1, 1, false, true)) == "Claimed", "server auto-claims it")
	end)

	test("ratio: bounded 0..1, invalid target safe", function()
		assert(QuestLog.ratio(q("A", 2, 5)) == 0.4)
		assert(QuestLog.ratio(q("A", 9, 5)) == 1 and QuestLog.ratio(q("A", -3, 5)) == 0)
		assert(QuestLog.ratio({ Id = "A", Progress = 0, Target = 0, Completed = false }) == 0)
	end)

	test("sorted: claimable first, then in progress, then claimed (latest first); input untouched", function()
		local list = { q("Q1", 1, 1, true), q("Q2", 1, 1, true), q("Q3", 0, 1), q("Q4", 1, 1) }
		local out = QuestLog.sorted(list)
		local ids = {}
		for _, e in out do table.insert(ids, e.Id) end
		assert(table.concat(ids, ",") == "Q4,Q3,Q2,Q1", table.concat(ids, ","))
		assert(list[1].Id == "Q1", "copy")
	end)

	test("claimable count and summary text", function()
		assert(QuestLog.claimable({ q("A", 1, 1), q("B", 1, 1), q("C", 0, 1) }) == 2)
		assert(QuestLog.summary({ q("A", 1, 1), q("C", 0, 1) }) == "1 récompense à récupérer", "claim first")
		assert(QuestLog.summary({ q("A", 1, 1), q("B", 1, 1) }) == "2 récompenses à récupérer")
		assert(QuestLog.summary({ q("A", 1, 1, true), q("C", 0, 3) }) == "1 quête en cours")
		assert(QuestLog.summary({ q("A", 1, 1, true) }) == "Toutes les quêtes sont terminées")
		assert(QuestLog.summary({}) == "Toutes les quêtes sont terminées")
	end)

	test("attention: reward to claim (absolute priority), new active quest not yet seen, nothing otherwise", function()
		assert(QuestLog.attention(nil, nil) == false)
		assert(QuestLog.attention(q("Q2", 1, 1), "Q2") == true, "claimable even if seen")
		assert(QuestLog.attention(q("Q2", 1, 1), nil) == true, "claimable at join too")
		assert(QuestLog.attention(q("Q2", 0, 1), nil) == false, "join: current quest counts as seen")
		assert(QuestLog.attention(q("Q3", 0, 1), "Q2") == true, "a new quest was activated")
		assert(QuestLog.attention(q("Q3", 0, 1), "Q3") == false, "seen in the panel")
		assert(QuestLog.attention(q("S", 1, 1, false, true), "X") == false, "auto-claimed quest: no badge")
	end)

	test("after a successful claim the next view drops the badge (unless it is new)", function()
		-- serveur : Q2 réclamée, Q3 active à 0 ; le panneau était ouvert (Q3 vue en direct)
		assert(QuestLog.attention(q("Q3", 0, 1), "Q3") == false)
		-- chaîne terminée : plus de quête active
		assert(QuestLog.attention(nil, "Q3") == false)
	end)

	print(`QuestLog: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} QuestLog test(s) failed`)
	end
end
