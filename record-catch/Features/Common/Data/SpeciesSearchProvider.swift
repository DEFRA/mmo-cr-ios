import Foundation

/// Supplies the species a user can search for on the Add-species screen.
///
/// API-shaped: `async throws` so a future real Species API can swap in without changing
/// `AddSpeciesViewModel` or its tests (see ADR-0004). Stubbed for now.
nonisolated protocol SpeciesSearchProviding: Sendable {
    /// Species whose name contains `query` (case-insensitive), or an empty list when `query` is
    /// shorter than `minimumCharacters`.
    func searchSpecies(matching query: String) async throws -> [SpeciesOption]

    /// The full set of species, used to seed a locally-filtering search field. A real API-backed
    /// implementation may page or cache; the stub returns its static list.
    func allSpecies() async throws -> [SpeciesOption]
}

/// Static, UI-only species search. Stands in until a real Species API exists.
///
/// Mirrors `StubPortSearchProvider`: a deterministic in-memory list with a minimum-characters
/// threshold before results appear.
nonisolated struct StubSpeciesSearchProvider: SpeciesSearchProviding {

    /// Minimum characters before any results are returned (matches the search field's default).
    let minimumCharacters: Int
    private let species: [SpeciesOption]

    init(
        minimumCharacters: Int = 2,
        names: [String] = StubSpeciesSearchProvider.defaultNames
    ) {
        self.minimumCharacters = minimumCharacters
        self.species = names.map(SpeciesOption.init(name:))
    }

    /// The stubbed species list for this phase, sourced from the FAO species reference list
    /// (`"<Title> (<FAOCode>)"`), sorted alphabetically by title.
    static let defaultNames = [
        "Albacore (ALB)",
        "Alfonsinos nei (ALF)",
        "Allis and twaite shads (SHD)",
        "Amberjacks nei (AMX)",
        "Angelshark (AGN)",
        "Angler(=Monk) (MON)",
        "Anglerfishes nei (ANF)",
        "Arctic skate (RJG)",
        "Argentines (ARG)",
        "Atlantic bluefin tuna (BFT)",
        "Atlantic bonito (BON)",
        "Atlantic cod (COD)",
        "Atlantic halibut (HAL)",
        "Atlantic herring (HER)",
        "Atlantic horse mackerel (HOM)",
        "Atlantic mackerel (MAC)",
        "Atlantic pomfret (POA)",
        "Atlantic redfishes nei (RED)",
        "Atlantic salmon (SAL)",
        "Atlantic thornyhead (TJX)",
        "Atlantic wolffish (CAA)",
        "Axillary seabream (SBA)",
        "Baird's slickhead (ALC)",
        "Ballan wrasse (USB)",
        "Beaked redfish (REB)",
        "Bigeye tuna (BET)",
        "Birdbeak dogfish (DCA)",
        "Black dogfish (CFB)",
        "Black scabbardfish (BSF)",
        "Black seabream (BRB)",
        "Blackbellied angler (ANK)",
        "Blackmouth catshark (SHO)",
        "Blackspot(=red) seabream (SBR)",
        "Blonde ray (RJH)",
        "Blue ling (BLI)",
        "Blue mussel (MUS)",
        "Blue shark (BSH)",
        "Blue skate (RJB)",
        "Blue whiting(=Poutassou) (WHB)",
        "Bluntnose sixgill shark (SBL)",
        "Boarfish (BOC)",
        "Bogue (BOG)",
        "Brill (BLL)",
        "Capelin (CAP)",
        "Catsharks, etc. nei (SYX)",
        "Catsharks, nursehounds nei (SCL)",
        "Clams, etc. nei (CLX)",
        "Common cuttlefish (CTC)",
        "Common dab (DAB)",
        "Common edible cockle (COC)",
        "Common octopus (OCC)",
        "Common prawn (CPR)",
        "Common shrimp (CSH)",
        "Common sole (SOL)",
        "Common spiny lobster (SLO)",
        "Common squids nei (SQC)",
        "Common stingray (JDP)",
        "Conger eels, etc. nei (COX)",
        "Corkwing wrasse (YFM)",
        "Craylets, squat lobsters nei (LOQ)",
        "Cuckoo ray (RJN)",
        "Cuckoo wrasse (USI)",
        "Cuttlefish, bobtail squids nei (CTL)",
        "Dogfish sharks nei (DGX)",
        "Dogfishes and hounds nei (DGH)",
        "Dragonet (LYY)",
        "Dusky grouper (GPD)",
        "Edible crab (CRE)",
        "Elegant cuttlefish (EJE)",
        "European anchovy (ANE)",
        "European conger (COE)",
        "European eel (ELE)",
        "European flat oyster (OYF)",
        "European flounder (FLE)",
        "European flying squid (SQE)",
        "European hake (HKE)",
        "European lobster (LBE)",
        "European pilchard(=Sardine) (PIL)",
        "European plaice (PLE)",
        "European seabass (BSS)",
        "European smelt (SME)",
        "European sprat (SPR)",
        "European squid (SQR)",
        "Forkbeard (FOR)",
        "Four-spot megrim (LDB)",
        "Frigate and bullet tunas (FRZ)",
        "Frilled shark (HXC)",
        "Garfish (GAR)",
        "Gilthead seabream (SBG)",
        "Goldsinny-wrasse (TBR)",
        "Great Atlantic scallop (SCE)",
        "Great lanternshark (ETR)",
        "Greater amberjack (AMB)",
        "Greater forkbeard (GFB)",
        "Greater weever (WEG)",
        "Green crab (CRG)",
        "Greenland halibut (GHL)",
        "Greenland shark (GSK)",
        "Grey gurnard (GUG)",
        "Grunts, sweetlips nei (GRX)",
        "Gulper shark (GUP)",
        "Gurnards, searobins nei (GUX)",
        "Haddock (HAD)",
        "Horned and musky octopuses (OCM)",
        "Horned octopus (EOI)",
        "Inshore squids nei (SQZ)",
        "Jack and horse mackerels nei (JAX)",
        "John dory (JOD)",
        "King crabs, stone crabs nei (KCX)",
        "Kitefin shark (SCK)",
        "Knifetooth dogfish (SYR)",
        "Lanternfishes nei (LXX)",
        "Large-eyed rabbitfish (CYH)",
        "Leafscale gulper shark (GUQ)",
        "Lemon sole (LEM)",
        "Ling (LIN)",
        "Longnose velvet dogfish (CYP)",
        "Longnosed skate (RJO)",
        "Lumpfish(=Lumpsucker) (LUM)",
        "Mako sharks (MAK)",
        "Manila clam (CMM)",
        "Marbled electric ray (TTR)",
        "Marine fishes nei (MZZ)",
        "Marlins,sailfishes,etc. nei (BIL)",
        "Meagre (MGR)",
        "Mediterranean slimehead (HPR)",
        "Megrim (MEG)",
        "Megrims nei (LEZ)",
        "Monkfishes nei (MNZ)",
        "Mouse catshark (GAM)",
        "Mullets nei (MUL)",
        "Northern prawn (PRA)",
        "Northern quahog(=Hard clam) (CLH)",
        "Northern shortfin squid (SQI)",
        "Norway lobster (NEP)",
        "Norway pout (NOP)",
        "Norwegian skate (JAD)",
        "Nursehound (SYT)",
        "Octopuses nei (OCZ)",
        "Octopuses, etc. nei (OCT)",
        "Orange roughy (ORY)",
        "Pacific chub mackerel (MAS)",
        "Pacific cupped oyster (OYG)",
        "Palinurid spiny lobsters nei (CRW)",
        "Pandalus shrimps nei (PAN)",
        "Periwinkles nei (PER)",
        "Picked dogfish (DGS)",
        "Pink cuttlefish (IAR)",
        "Pollack (POL)",
        "Pompanos nei (POX)",
        "Porbeagle (POR)",
        "Porgies, seabreams nei (SBX)",
        "Portuguese dogfish (CYO)",
        "Pouting(=Bib) (BIB)",
        "Queen scallop (QSC)",
        "Queen snapper (EEO)",
        "Rabbit fish (CMO)",
        "Red gurnard (GUR)",
        "Red mullet (MUT)",
        "Red scorpionfish (RSE)",
        "Rock cook (ENX)",
        "Rocklings nei (ROL)",
        "Roughhead grenadier (RHG)",
        "Round ray (RJY)",
        "Roundnose grenadier (RNG)",
        "Rudderfish (CEO)",
        "Sailfin roughshark (OXN)",
        "Saithe (POK)",
        "Sand gaper (CLS)",
        "Sand smelt (ATP)",
        "Sand sole (SOS)",
        "Sandeels(=Sandlances) nei (SAN)",
        "Sandy ray (RJI)",
        "Sea catfishes nei (CAX)",
        "Sea cucumbers nei (CUX)",
        "Sea trout (TRS)",
        "Sea urchins nei (URC)",
        "Shagreen ray (RJF)",
        "Small-eyed ray (RJE)",
        "Small-spotted catshark (SYC)",
        "Smooth-hound (SMD)",
        "Solen razor clams nei (RAZ)",
        "Soles nei (SOX)",
        "Spinous spider crab (SCR)",
        "Spotted ray (RJM)",
        "Starfishes nei (STF)",
        "Starry ray (RJR)",
        "Starry smooth-hound (SDS)",
        "Sturgeons nei (STU)",
        "Sunfish (MOP)",
        "Surmullet (MUR)",
        "Thickback sole (MKG)",
        "Thornback ray (RJC)",
        "Tope shark (GAG)",
        "Topknot (ZGP)",
        "Triggerfishes, durgons nei (TRI)",
        "Tub gurnard (GUU)",
        "Turbot (TUR)",
        "Tusk(=Cusk) (USK)",
        "Undulate ray (RJU)",
        "Various squids nei (SQU)",
        "Velvet belly (ETX)",
        "Velvet swimcrab (LIO)",
        "Venus clams nei (CLV)",
        "Whelk (WHE)",
        "White skate (RJA)",
        "Whiting (WHG)",
        "Witch flounder (WIT)",
        "Wrasses, hogfishes, etc. nei (WRA)",
        "Wreckfish (WRF)",
        "Yellowfin tuna (YFT)",
        "Yellowtail amberjack (YTC)",
        "Yellowtail flounder (YEL)",
        "Zebra seabream (SBZ)"
    ]

    func searchSpecies(matching query: String) async throws -> [SpeciesOption] {
        Self.filtered(query: query, minimumCharacters: minimumCharacters, species: species)
    }

    func allSpecies() async throws -> [SpeciesOption] {
        species
    }

    /// Pure filtering, exposed for unit testing without awaiting the async surface.
    static func filtered(
        query: String,
        minimumCharacters: Int,
        species: [SpeciesOption]
    ) -> [SpeciesOption] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumCharacters else { return [] }
        return species.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}
