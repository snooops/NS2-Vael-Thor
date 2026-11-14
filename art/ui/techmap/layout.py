# Vael'Thor tech map layout: (techId suffix, x, y) top-left in icon units, like vanilla MarineTechMap.
NODES = [
    ("VTSiphon", 5, 1), ("VTNexus", 7, 1), ("VTSubventionPylon", 9, 1), ("VTResonantPylonUpgrade", 10.5, 1),
    ("VTNexusGate", 5, 2.5), ("VTNexusRecall", 3.5, 2.5),
    ("VTSynthesisChamber", 7, 4),
    ("VTOverchargeTech", 3.5, 4), ("VTPhaseDashTech", 5, 4),
    ("VTPlasmaCalibration1", 9, 3.5), ("VTPlasmaCalibration2", 10.5, 3.5), ("VTPlasmaCalibration3", 12, 3.5),
    ("VTShieldMatrix1", 9, 4.5), ("VTShieldMatrix2", 10.5, 4.5), ("VTShieldMatrix3", 12, 4.5),
    ("VTShieldGenerator", 4.5, 6), ("VTTargetingVisorTech", 3, 6), ("VTAegisArrayUpgrade", 3, 7.25),
    ("VTSentinelObelisk", 9.5, 6), ("VTObeliskPrismUpgrade", 11, 6), ("VTObeliskTrinityUpgrade", 12.5, 6),
    ("VTAuthorizationTier2", 7, 7),
    ("VTArchonsThrone", 5.5, 8.25), ("VTEdictIronDiscipline", 4, 8.25),
    ("VTShieldOverdriveTech", 8.5, 7),
    ("VTAuthorizationTier3", 7, 9.5), ("VTSingularityTech", 5.5, 9.5), ("VTSingularityLauncher", 4, 9.5),
    ("VTPsionicSpire", 10.5, 9.5),
    ("VTPhaseCloakTech", 9.5, 11), ("VTNeuralOverrideTech", 11, 11), ("VTPsionicEdictsTech", 12.5, 11),
]
EDGES = [
    ("VTNexus", "VTSiphon"), ("VTNexus", "VTSubventionPylon"), ("VTSubventionPylon", "VTResonantPylonUpgrade"),
    ("VTNexus", "VTNexusGate"), ("VTNexusGate", "VTNexusRecall"),
    ("VTNexus", "VTSynthesisChamber"),
    ("VTSynthesisChamber", "VTPhaseDashTech"), ("VTPhaseDashTech", "VTOverchargeTech"),
    ("VTSynthesisChamber", "VTPlasmaCalibration1"), ("VTPlasmaCalibration1", "VTPlasmaCalibration2"), ("VTPlasmaCalibration2", "VTPlasmaCalibration3"),
    ("VTSynthesisChamber", "VTShieldMatrix1"), ("VTShieldMatrix1", "VTShieldMatrix2"), ("VTShieldMatrix2", "VTShieldMatrix3"),
    ("VTSynthesisChamber", "VTShieldGenerator"), ("VTShieldGenerator", "VTTargetingVisorTech"), ("VTShieldGenerator", "VTAegisArrayUpgrade"),
    ("VTSynthesisChamber", "VTSentinelObelisk"), ("VTSentinelObelisk", "VTObeliskPrismUpgrade"), ("VTObeliskPrismUpgrade", "VTObeliskTrinityUpgrade"),
    ("VTSynthesisChamber", "VTAuthorizationTier2"),
    ("VTAuthorizationTier2", "VTArchonsThrone"), ("VTArchonsThrone", "VTEdictIronDiscipline"),
    ("VTAuthorizationTier2", "VTShieldOverdriveTech"),
    ("VTAuthorizationTier2", "VTAuthorizationTier3"), ("VTAuthorizationTier3", "VTSingularityTech"), ("VTSingularityTech", "VTSingularityLauncher"),
    ("VTAuthorizationTier2", "VTPsionicSpire"),
    ("VTPsionicSpire", "VTPhaseCloakTech"), ("VTPsionicSpire", "VTNeuralOverrideTech"), ("VTPsionicSpire", "VTPsionicEdictsTech"),
]
YSTART = 1   # kVTTechMapYStart (vanilla marine: 2); background is 15 x 15 icons
