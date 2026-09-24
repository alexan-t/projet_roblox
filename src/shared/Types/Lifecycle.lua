--!strict
-- Contrat des modules chargés par les bootstraps (Services côté serveur, Controllers côté client).
--   Init()  : préparation locale au module, sans appeler les autres modules.
--   Start() : démarrage, tous les modules ont déjà fini leur Init().
-- Les deux méthodes sont optionnelles.

export type Module = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

return {}
