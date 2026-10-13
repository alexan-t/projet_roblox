--!strict
-- Recherche des animations d'un modèle dans ReplicatedStorage.Assets.Animations (voir docs/SKELETON.md).
-- Ordre des jeux : Skeleton.animationSets (jeu propre, puis jeu commun du squelette).
-- Un jeu d'aperçu d'atelier (attribut Apercu = true, posé par AnimationKit.preview) se suffit à
-- lui-même : il arrête la recherche ; en combat (combat = true), il est ignoré.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skeleton = require(script.Parent.Skeleton)

local AnimationSets = {}

function AnimationSets.attributes(model: Instance): Skeleton.SetAttributes
	return {
		JeuAnimations = model:GetAttribute("JeuAnimations"),
		JeuAnimationsCombat = model:GetAttribute("JeuAnimationsCombat"),
		JeuAnimationsCommun = model:GetAttribute("JeuAnimationsCommun"),
		Squelette = model:GetAttribute("Squelette"),
	}
end

-- Le modèle déclare au moins un jeu d'animations.
function AnimationSets.isAnimated(model: Instance): boolean
	return #Skeleton.animationSets(AnimationSets.attributes(model), true) > 0
end

-- Dossiers des jeux à consulter, du plus prioritaire au moins prioritaire.
function AnimationSets.folders(model: Instance, combat: boolean?): { Instance }
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animations = assets and assets:FindFirstChild("Animations")
	local folders: { Instance } = {}
	if not animations then
		return folders
	end
	for _, name in Skeleton.animationSets(AnimationSets.attributes(model), combat) do
		local folder = animations:FindFirstChild(name)
		if not folder then
			continue
		end
		local preview = folder:GetAttribute("Apercu") == true
		if preview and combat then
			continue
		end
		table.insert(folders, folder)
		if preview then
			break
		end
	end
	return folders
end

-- Séquences du modèle par nom (Attente, Marche, Attaque...) : la première trouvée l'emporte.
function AnimationSets.sequences(model: Instance, combat: boolean?): { [string]: KeyframeSequence }
	local found: { [string]: KeyframeSequence } = {}
	for _, folder in AnimationSets.folders(model, combat) do
		for _, sequence in folder:GetChildren() do
			if sequence:IsA("KeyframeSequence") and not found[sequence.Name] then
				found[sequence.Name] = sequence
			end
		end
	end
	return found
end

function AnimationSets.find(model: Instance, name: string, combat: boolean?): KeyframeSequence?
	for _, folder in AnimationSets.folders(model, combat) do
		local sequence = folder:FindFirstChild(name)
		if sequence and sequence:IsA("KeyframeSequence") then
			return sequence
		end
	end
	return nil
end

-- Pièces visibles rattachées à un os (attribut Os posé par AnimationKit.rig).
-- Sans squelette commun : liste vide (l'appelant garde son ancienne recherche).
function AnimationSets.pieces(model: Instance, boneName: string): { BasePart }
	local list: { BasePart } = {}
	if model:GetAttribute("Squelette") ~= Skeleton.Name then
		return list
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute(Skeleton.BoneAttribute) == boneName then
			table.insert(list, part)
		end
	end
	return list
end

return AnimationSets
