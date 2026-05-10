import Foundation
import MapKit

//
// StaticData.swift
// Theme park attraction reference data for Walt Disney World + Universal Orlando.
//
// Attraction IDs are queue-times.com ride IDs, verified against
// /parks/{park}/queue_times on 2026-05-09.
//
// Land mapping uses short, human-friendly names (not always identical to
// queue-times' canonical land naming, which sometimes splits pavilions).
//
// Maintenance notes:
//   - Disney/Universal change rides constantly. Verify operational status
//     against queue-times.com before relying on this data.
//   - When queue-times reorganizes IDs (as happened with USF mid-2024),
//     this file's IDs go stale. Consider hybrid: static metadata here,
//     live operational status from the API.
//

struct StaticData {
    // MARK: - Park & Resort Data

    static let parkIdToName: [Int: String] = [
        5: "EPCOT",
        6: "Magic Kingdom Park",
        7: "Disney's Hollywood Studios",
        8: "Disney's Animal Kingdom",
        64: "Universal's Islands of Adventure",
        65: "Universal Studios Florida",
        334: "Universal's Epic Universe"
    ]

    static let resortGroupData: [String: [Int]] = [
        "Walt Disney World": [5, 6, 7, 8],
        "Universal Orlando Resort": [64, 65, 334]
    ]

    // Park entrance/center coordinates verified against queue-times.com
    static let parkCoordinates: [Int: (lat: Double, lon: Double)] = [
        5:   (28.374694, -81.549404),
        6:   (28.417663, -81.581212),
        7:   (28.357529, -81.558271),
        8:   (28.353067, -81.591194),
        64:  (28.472243, -81.467856),
        65:  (28.474982, -81.466497),
        334: (28.441445, -81.448674)
    ]

    /// Maps our internal queue-times int parkId to the ThemeParks.wiki UUID.
    /// Used by `ThemeParksWikiClient` to fetch the same park from the new API.
    static let parkUUIDByInternalId: [Int: String] = [
        5:   "47f90d2c-e191-4239-a466-5892ef59a88b", // EPCOT
        6:   "75ea578a-adc8-4116-a54d-dccb60765ef9", // Magic Kingdom Park
        7:   "288747d1-8b4f-4a64-867e-ea7c9b27bad8", // Disney's Hollywood Studios
        8:   "1c84a229-8862-4648-9c71-378ddd2c7693", // Disney's Animal Kingdom
        64:  "267615cc-8943-4c2a-ae2c-5da728ca591f", // Universal Islands of Adventure
        65:  "eb3f4560-2383-4a36-9152-6b3e5ed6bc57", // Universal Studios Florida
        334: "12dbb85b-265f-44e6-bccf-f1faa17211fc"  // Universal Epic Universe
    ]

    /// Cached normalized-name → internal int ID lookup, built on first access
    /// from `attractionsJSON`. Used to resolve ThemeParks.wiki entities (which
    /// expose UUIDs) back to the int IDs the rest of the app keys off of.
    private static let normalizedNameIndex: [String: Int] = {
        var index: [String: Int] = [:]
        for (id, details) in getAttractionDetails() {
            let key = normalizeAttractionName(details.name)
            // Prefer the lower internal ID on collision — keeps results stable
            // when two static rows share the same normalized name.
            if let existing = index[key], existing < id { continue }
            index[key] = id
        }
        return index
    }()

    /// Normalize an attraction name for cross-source matching: case-fold,
    /// strip trademark/punctuation noise, fold smart quotes/dashes, and
    /// collapse whitespace. Stable across queue-times and ThemeParks.wiki.
    static func normalizeAttractionName(_ name: String) -> String {
        var s = name.lowercased()
        // Drop trademark/copyright marks.
        for marker in ["™", "®", "©"] { s = s.replacingOccurrences(of: marker, with: "") }
        // Fold smart punctuation to ASCII equivalents.
        let folds: [(String, String)] = [
            ("’", "'"), ("‘", "'"), ("“", "\""), ("”", "\""),
            ("–", "-"), ("—", "-"), ("…", "..."),
            (" & ", " and ")
        ]
        for (from, to) in folds { s = s.replacingOccurrences(of: from, with: to) }
        // Strip remaining punctuation we don't care about for matching.
        let stripped = s.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == " "
        }
        s = String(String.UnicodeScalarView(stripped))
        // Collapse runs of whitespace.
        s = s.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        return s
    }

    /// Look up the internal int attraction ID for a name from any source.
    /// Returns nil if the name doesn't match any known static attraction.
    static func internalAttractionId(forName name: String) -> Int? {
        normalizedNameIndex[normalizeAttractionName(name)]
    }

    /// Approximate year-round operating hours per park (open/close in 24h local time).
    /// These are sensible defaults; real hours vary daily — pull from the queue-times
    /// API or queue-times.com/parks/{id}/calendar for accurate per-day hours.
    static let parkHours: [Int: (openHour: Int, closeHour: Int)] = [
        5:   (9, 21),
        6:   (9, 22),
        7:   (9, 21),
        8:   (8, 19),
        64:  (9, 21),
        65:  (9, 21),
        334: (9, 22)
    ]

    /// Best-guess indoor classification by attraction type. Used to bias
    /// recommendations toward shaded/AC rides on hot days.
    static func isLikelyIndoor(type: String?) -> Bool {
        switch (type ?? "").lowercased() {
        case "darkride", "simulator", "show", "theater", "3dfilm", "film", "stage":
            return true
        default:
            return false
        }
    }

    static func buildResortGroups() -> [ResortGroup] {
        let sortedResortNames = resortGroupData.keys.sorted()
        return sortedResortNames.map { resortName in
            let parkIDs = resortGroupData[resortName] ?? []
            let parks = parkIDs.compactMap { id -> Park? in
                guard let parkName = parkIdToName[id] else { return nil }
                return Park(id: id, name: parkName)
            }
            return ResortGroup(name: resortName, parks: parks.sorted(by: { $0.name < $1.name }))
        }
    }

    // MARK: - Attraction Details & Mappings

    private struct AttractionDetail: Decodable {
        let id: Int
        let parkId: Int
        let name: String
        let type: String?
        let description: String?
        let minHeight: Int?
        let latitude: Double?
        let longitude: Double?
        let tpwUuid: String?
    }

    static func getAttractionDetails() -> [Int: (name: String, parkId: Int, type: String?, description: String?, minHeight: Int?, lat: Double?, lon: Double?, tpwUuid: String?)] {
        guard let data = attractionsJSON.data(using: .utf8) else {
            fatalError("Could not convert static attractions JSON string to Data.")
        }
        do {
            let details = try JSONDecoder().decode([AttractionDetail].self, from: data)
            var detailsMap = [Int: (name: String, parkId: Int, type: String?, description: String?, minHeight: Int?, lat: Double?, lon: Double?, tpwUuid: String?)]()
            for detail in details {
                detailsMap[detail.id] = (detail.name, detail.parkId, detail.type, detail.description, detail.minHeight, detail.latitude, detail.longitude, detail.tpwUuid)
            }
            return detailsMap
        } catch {
            fatalError("Error decoding static attraction details: \(error)")
        }
    }

    /// Returns the themeparks.wiki UUID for an attraction, if known.
    /// Use this to query https://api.themeparks.wiki/v1/entity/{uuid}/live
    /// for richer live data than queue-times provides (forecast, return-time
    /// availability, dining availability, etc.).
    static func themeparksWikiUuid(for attractionId: Int) -> String? {
        getAttractionDetails()[attractionId]?.tpwUuid
    }

    static func getStaticAttractions(for parkId: Int) -> [Attraction] {
        let allAttractionDetails = getAttractionDetails()
        let parkAttractions = allAttractionDetails.filter { $0.value.parkId == parkId }
        return parkAttractions.map { id, details in
            Attraction(id: id,
                       name: details.name,
                       wait_time: nil,
                       status: "N/A",
                       is_open: true,
                       last_updated: nil,
                       type: details.type,
                       description: details.description,
                       min_height_inches: details.minHeight,
                       latitude: details.lat,
                       longitude: details.lon)
        }
    }

    static func getOfflineAttractions(for parkId: Int) -> [Attraction] {
        getStaticAttractions(for: parkId)
    }

    static func statusOverride(for attractionId: Int) -> String? {
        nil
    }

    // Land mapping: maps queue-times ride IDs to short, human-friendly land names.
    static let attractionToLandMapping: [Int: String] = [
        // ─── MAGIC KINGDOM ───
        // Adventureland
        134: "Adventureland",  // Jungle Cruise
        137: "Adventureland",  // Pirates of the Caribbean
        141: "Adventureland",  // The Magic Carpets of Aladdin
        334: "Adventureland",  // Walt Disney's Enchanted Tiki Room
        355: "Adventureland",  // Swiss Family Treehouse
        1184: "Adventureland",  // A Pirate's Adventure ~ Treasures of the Seven Seas
        // Fantasyland
        126: "Fantasyland",  // The Barnstormer
        127: "Fantasyland",  // Under the Sea - Journey of The Little Mermaid
        128: "Fantasyland",  // Enchanted Tales with Belle
        129: "Fantasyland",  // Seven Dwarfs Mine Train
        132: "Fantasyland",  // Dumbo the Flying Elephant
        133: "Fantasyland",  // "it's a small world"
        135: "Fantasyland",  // Mad Tea Party
        136: "Fantasyland",  // Peter Pan's Flight
        142: "Fantasyland",  // The Many Adventures of Winnie the Pooh
        147: "Fantasyland",  // Meet Ariel at Her Grotto
        161: "Fantasyland",  // Prince Charming Regal Carrousel
        171: "Fantasyland",  // Mickey's PhilharMagic
        1181: "Fantasyland",  // Walt Disney World Railroad - Fantasyland
        6699: "Fantasyland",  // Meet Princess Tiana and a Visiting Princess at Princess Fairytale Hall
        6700: "Fantasyland",  // Meet Cinderella and a Visiting Princess at Princess Fairytale Hall
        13763: "Fantasyland",  // Cinderella Castle
        13764: "Fantasyland",  // Casey Jr. Splash 'N' Soak Station
        // Frontierland
        130: "Frontierland",  // Big Thunder Mountain Railroad
        1214: "Frontierland",  // Country Bear Musical Jamboree
        13630: "Frontierland",  // Tiana's Bayou Adventure
        // Liberty Square
        140: "Liberty Square",  // Haunted Mansion
        356: "Liberty Square",  // The Hall of Presidents
        // Main Street, U.S.A.
        146: "Main Street, U.S.A.",  // Meet Mickey at Town Square Theater
        1188: "Main Street, U.S.A.",  // Main Street Vehicles
        1189: "Main Street, U.S.A.",  // Walt Disney World Railroad - Main Street, U.S.A.
        // Tomorrowland
        125: "Tomorrowland",  // Monsters Inc. Laugh Floor
        131: "Tomorrowland",  // Buzz Lightyear's Space Ranger Spin
        138: "Tomorrowland",  // Space Mountain
        143: "Tomorrowland",  // Tomorrowland Speedway
        248: "Tomorrowland",  // Astro Orbiter
        457: "Tomorrowland",  // Walt Disney's Carousel of Progress
        1190: "Tomorrowland",  // Tomorrowland Transit Authority PeopleMover
        11527: "Tomorrowland",  // TRON Lightcycle / Run

        // ─── EPCOT ───
        // World Celebration
        159: "World Celebration",  // Spaceship Earth
        13627: "World Celebration",  // Meet Beloved Disney Pals at Mickey & Friends
        13775: "World Celebration",  // Project Tomorrow: Inventing the Wonders of the Future
        // World Discovery
        158: "World Discovery",  // Mission: SPACE
        160: "World Discovery",  // Test Track
        10900: "World Discovery",  // Test Track Single Rider
        10916: "World Discovery",  // Guardians of the Galaxy: Cosmic Rewind
        13774: "World Discovery",  // Advanced Training Lab
        // World Nature
        151: "World Nature",  // Soarin' Around the World
        152: "World Nature",  // Turtle Talk With Crush
        153: "World Nature",  // The Seas with Nemo & Friends
        155: "World Nature",  // Journey Into Imagination With Figment
        156: "World Nature",  // Living with the Land
        2495: "World Nature",  // Disney and Pixar Short Film Festival
        7323: "World Nature",  // Awesome Planet
        12387: "World Nature",  // Journey of Water, Inspired by Moana
        13770: "World Nature",  // Bruce's Shark World
        13777: "World Nature",  // ImageWorks - The "What If" Labs
        13782: "World Nature",  // SeaBase Aquarium
        // World Showcase
        466: "World Showcase",  // Gran Fiesta Tour Starring The Three Caballeros
        829: "World Showcase",  // Canada Far and Wide in Circle-Vision 360
        2679: "World Showcase",  // Frozen Ever After
        6701: "World Showcase",  // Meet Anna and Elsa at Royal Sommerhus
        10914: "World Showcase",  // Remy's Ratatouille Adventure
        10915: "World Showcase",  // Remy's Ratatouille Adventure Single Rider
        13767: "World Showcase",  // House of the Whispering Willows
        13772: "World Showcase",  // Gallery of Arts and History
        13773: "World Showcase",  // American Heritage Gallery
        13776: "World Showcase",  // Stave Church Gallery
        13778: "World Showcase",  // Kidcot Fun Stops
        13779: "World Showcase",  // Palais du Cinéma
        13780: "World Showcase",  // Mexico Folk Art Gallery
        13781: "World Showcase",  // Bijutsu-kan Gallery

        // ─── HOLLYWOOD STUDIOS ───
        // Commissary Lane
        6704: "Commissary Lane",  // Meet Disney Stars at Red Carpet Dreams
        // Echo Lake
        120: "Echo Lake",  // Star Tours – The Adventures Continue
        1174: "Echo Lake",  // For the First Time in Forever: A Frozen Sing-Along Celebration
        6702: "Echo Lake",  // Indiana Jones Epic Stunt Spectacular!
        6703: "Echo Lake",  // Meet Olaf at Celebrity Spotlight
        7333: "Echo Lake",  // Vacation Fun - An Original Animated Short with Mickey & Minnie
        // Hollywood Boulevard
        6361: "Hollywood Boulevard",  // Mickey & Minnie's Runaway Railway
        // Pixar Plaza
        117: "Pixar Plaza",  // Toy Story Mania!
        12425: "Pixar Plaza",  // Meet Edna Mode at the Edna Mode Experience
        // Star Wars: Galaxy's Edge
        6368: "Star Wars: Galaxy's Edge",  // Millennium Falcon: Smugglers Run
        6369: "Star Wars: Galaxy's Edge",  // Star Wars: Rise of the Resistance
        10902: "Star Wars: Galaxy's Edge",  // Millennium Falcon: Smugglers Run Single Rider
        14531: "Star Wars: Galaxy's Edge",  // Star Wars: Rise of the Resistance Single Rider
        // Sunset Boulevard
        119: "Sunset Boulevard",  // Rock 'n' Roller Coaster Starring The Muppets
        123: "Sunset Boulevard",  // The Twilight Zone Tower of Terror
        1176: "Sunset Boulevard",  // Beauty and the Beast – Live on Stage
        10901: "Sunset Boulevard",  // Rock 'n' Roller Coaster Starring The Muppets Single Rider
        // The Walt Disney Studios
        5145: "The Walt Disney Studios",  // Walt Disney Presents
        12430: "The Walt Disney Studios",  // Meet Ariel at Walt Disney Presents
        14859: "The Walt Disney Studios",  // The Little Mermaid – A Musical Adventure
        // Toy Story Land
        5476: "Toy Story Land",  // Slinky Dog Dash
        5477: "Toy Story Land",  // Alien Swirling Saucers

        // ─── ANIMAL KINGDOM ───
        // Africa
        113: "Africa",  // Kilimanjaro Safaris
        651: "Africa",  // Gorilla Falls Exploration Trail
        655: "Africa",  // Wildlife Express Train
        657: "Africa",  // Festival of the Lion King
        // Asia
        110: "Asia",  // Expedition Everest - Legend of the Forbidden Mountain
        112: "Asia",  // Kali River Rapids
        10921: "Asia",  // Feathered Friends in Flight!
        14533: "Asia",  // Expedition Everest - Legend of the Forbidden Mountain Single Rider
        // Dinoland U.S.A.
        10920: "Dinoland U.S.A.",  // Finding Nemo: The Big Blue... and Beyond!
        // Discovery Island
        116: "Discovery Island",  // Meet Favorite Disney Pals at Adventurers Outpost
        12451: "Discovery Island",  // Meet Moana at Character Landing
        13751: "Discovery Island",  // Tree of Life
        13811: "Discovery Island",  // Discovery Island Trails
        14943: "Discovery Island",  // Zootopia: Better Zoogether!
        // Pandora - The World of Avatar
        4438: "Pandora - The World of Avatar",  // Na'vi River Journey
        4439: "Pandora - The World of Avatar",  // Avatar Flight of Passage
        // Rafiki's Planet Watch
        13806: "Rafiki's Planet Watch",  // Animal Care at Conservation Station
        13807: "Rafiki's Planet Watch",  // Affection Section
        // The Oasis
        13808: "The Oasis",  // Wilderness Explorers
        13812: "The Oasis",  // The Oasis Exhibits

        // ─── ISLANDS OF ADVENTURE ───
        // Jurassic Park
        5994: "Jurassic Park",  // Jurassic Park River Adventure
        5999: "Jurassic Park",  // Pteranodon Flyers
        6008: "Jurassic Park",  // Camp Jurassic
        6012: "Jurassic Park",  // Jurassic Park Discovery Center
        6017: "Jurassic Park",  // Skull Island: Reign of Kong
        8721: "Jurassic Park",  // Jurassic World VelociCoaster
        // Marvel Super Hero Island
        5985: "Marvel Super Hero Island",  // The Amazing Adventures of Spider-Man
        5988: "Marvel Super Hero Island",  // Doctor Doom's Fearfall
        6003: "Marvel Super Hero Island",  // Storm Force Accelatron
        6004: "Marvel Super Hero Island",  // The Incredible Hulk Coaster
        15384: "Marvel Super Hero Island",  // The Incredible Hulk Coaster Single Rider
        15411: "Marvel Super Hero Island",  // The Amazing Adventures of Spider-Man Single Rider
        // Seuss Landing
        5986: "Seuss Landing",  // Caro-Seuss-el
        5987: "Seuss Landing",  // The Cat in The Hat
        5997: "Seuss Landing",  // One Fish, Two Fish, Red Fish, Blue Fish
        6001: "Seuss Landing",  // The High in the Sky Seuss Trolley Train Ride!
        6011: "Seuss Landing",  // If I Ran The Zoo
        // The Wizarding World of Harry Potter - Hogsmeade
        5991: "The Wizarding World of Harry Potter - Hogsmeade",  // Flight of the Hippogriff
        5992: "The Wizarding World of Harry Potter - Hogsmeade",  // Harry Potter and the Forbidden Journey
        6015: "The Wizarding World of Harry Potter - Hogsmeade",  // Hogwarts Express - Hogsmeade Station
        6682: "The Wizarding World of Harry Potter - Hogsmeade",  // Hagrid's Magical Creatures Motorbike Adventure
        13098: "The Wizarding World of Harry Potter - Hogsmeade",  // Ollivanders Experience in Hogsmeade
        13113: "The Wizarding World of Harry Potter - Hogsmeade",  // Harry Potter and the Forbidden Journey Single Rider
        15403: "The Wizarding World of Harry Potter - Hogsmeade",  // Hagrid's Magical Creatures Motorbike Adventure Single Rider
        // Toon Lagoon
        5989: "Toon Lagoon",  // Dudley Do-Right's Ripsaw Falls
        5998: "Toon Lagoon",  // Popeye & Bluto's Bilge-Rat Barges
        6013: "Toon Lagoon",  // Me Ship, The Olive

        // ─── UNIVERSAL STUDIOS FLORIDA ───
        // DreamWorks Land
        13605: "DreamWorks Land",  // Trolls Trollercoaster
        // Hollywood
        5990: "Hollywood",  // E.T. Adventure
        // Illumination's Minion Land
        5984: "Illumination's Minion Land",  // Despicable Me Minion Mayhem
        12107: "Illumination's Minion Land",  // Illumination's Villain-Con Minion Blast
        12186: "Illumination's Minion Land",  // Illumination Theater
        // New York
        6000: "New York",  // Revenge of the Mummy
        6018: "New York",  // Race Through New York Starring Jimmy Fallon
        13110: "New York",  // Revenge of the Mummy Single Rider
        // Production Central
        5993: "Production Central",  // Hollywood Rip Ride Rockit
        6006: "Production Central",  // TRANSFORMERS: The Ride-3D
        // San Francisco
        6038: "San Francisco",  // Fast & Furious - Supercharged
        14866: "San Francisco",  // Fast & Furious - Supercharged Single Rider
        // The Wizarding World of Harry Potter - Diagon Alley
        6014: "The Wizarding World of Harry Potter - Diagon Alley",  // Harry Potter and the Escape from Gringotts
        6016: "The Wizarding World of Harry Potter - Diagon Alley",  // Hogwarts Express - King's Cross Station
        13100: "The Wizarding World of Harry Potter - Diagon Alley",  // Ollivanders Experience in Diagon Alley
        13849: "The Wizarding World of Harry Potter - Diagon Alley",  // Hogwarts Express - First Train
        15416: "The Wizarding World of Harry Potter - Diagon Alley",  // Harry Potter and the Escape from Gringotts Single Rider
        // World Expo
        5995: "World Expo",  // Kang & Kodos' Twirl 'n' Hurl
        5996: "World Expo",  // MEN IN BLACK Alien Attack!
        6005: "World Expo",  // The Simpsons Ride
        14517: "World Expo",  // MEN IN BLACK Alien Attack! Single Rider

        // ─── EPIC UNIVERSE ───
        // Celestial Park
        14688: "Celestial Park",  // Constellation Carousel
        14690: "Celestial Park",  // Stardust Racers
        14740: "Celestial Park",  // Stardust Racers Single Rider
        // Dark Universe
        14692: "Dark Universe",  // Curse of the Werewolf
        14694: "Dark Universe",  // Monsters Unchained: The Frankenstein Experiment
        14698: "Dark Universe",  // Curse of the Werewolf Single Rider
        14699: "Dark Universe",  // Monsters Unchained: The Frankenstein Experiment Single Rider
        // How to Train Your Dragon - Isle of Berk
        14685: "How to Train Your Dragon - Isle of Berk",  // Meet Toothless and Friends
        14691: "How to Train Your Dragon - Isle of Berk",  // Fyre Drill
        14693: "How to Train Your Dragon - Isle of Berk",  // Dragon Racer's Rally
        14695: "How to Train Your Dragon - Isle of Berk",  // Hiccup Wing Glider
        // Super Nintendo World
        14682: "Super Nintendo World",  // Bowser Jr. Challenge
        14683: "Super Nintendo World",  // Mario Kart: Bowser's Challenge
        14684: "Super Nintendo World",  // Mario Kart: Bowser's Challenge Single Rider
        14689: "Super Nintendo World",  // Yoshi's Adventure
        // Super Nintendo World - Donkey Kong Country
        14686: "Super Nintendo World - Donkey Kong Country",  // Mine-Cart Madness
        14697: "Super Nintendo World - Donkey Kong Country",  // Mine-Cart Madness Single Rider
        // The Wizarding World of Harry Potter - Ministry of Magic
        14687: "The Wizarding World of Harry Potter - Ministry of Magic",  // Harry Potter and the Battle at the Ministry
        14696: "The Wizarding World of Harry Potter - Ministry of Magic",  // Harry Potter and the Battle at the Ministry Single Rider

    ]

    /// Returns true if a land name looks seasonal (Halloween Horror Nights
    /// houses, holiday overlays, etc.).
    static func isSeasonalLand(_ landName: String) -> Bool {
        let lower = landName.lowercased()
        let seasonalKeywords = [
            "halloween",
            "horror",
            "scare",
            "haunted",
            "christmas",
            "holiday",
            "grinchmas",
            "mardi gras",
            "oktoberfest",
            "other attractions"
        ]
        return seasonalKeywords.contains { lower.contains($0) }
    }

    /// Preferred SF Symbol per specific attraction. When an ID appears here,
    /// `symbol(for:)` returns its thematic symbol instead of the type-based fallback.
    static let attractionSymbolOverrides: [Int: String] = [
        // ─── MAGIC KINGDOM ───
        125: "theatermasks.fill",  // Monsters Inc. Laugh Floor
        126: "airplane",  // The Barnstormer
        127: "fish.fill",  // Under the Sea - Journey of The Little Mermaid
        128: "book.closed.fill",  // Enchanted Tales with Belle
        129: "hammer.fill",  // Seven Dwarfs Mine Train
        130: "mountain.2.fill",  // Big Thunder Mountain Railroad
        131: "scope",  // Buzz Lightyear's Space Ranger Spin
        132: "bird",  // Dumbo the Flying Elephant
        133: "globe.europe.africa.fill",  // "it's a small world"
        134: "ferry.fill",  // Jungle Cruise
        135: "cup.and.saucer.fill",  // Mad Tea Party
        136: "airplane.circle.fill",  // Peter Pan's Flight
        137: "sailboat.fill",  // Pirates of the Caribbean
        138: "sparkles",  // Space Mountain
        140: "house.lodge.fill",  // Haunted Mansion
        141: "fan.oscillation.fill",  // The Magic Carpets of Aladdin
        142: "teddybear.fill",  // The Many Adventures of Winnie the Pooh
        143: "car.side.fill",  // Tomorrowland Speedway
        146: "person.bust.fill",  // Meet Mickey at Town Square Theater
        147: "fish",  // Meet Ariel at Her Grotto
        161: "figure.equestrian.sports",  // Prince Charming Regal Carrousel
        171: "music.note",  // Mickey's PhilharMagic
        248: "airplane.circle.fill",  // Astro Orbiter
        334: "bird.fill",  // Walt Disney's Enchanted Tiki Room
        355: "tree.fill",  // Swiss Family Treehouse
        356: "building.columns.fill",  // The Hall of Presidents
        457: "gearshape.2.fill",  // Walt Disney's Carousel of Progress
        1181: "tram.fill",  // Walt Disney World Railroad - Fantasyland
        1184: "map.fill",  // A Pirate's Adventure ~ Treasures of the Seven Seas
        1188: "car.rear.fill",  // Main Street Vehicles
        1189: "tram.fill",  // Walt Disney World Railroad - Main Street, U.S.A.
        1190: "tram.fill",  // Tomorrowland Transit Authority PeopleMover
        1214: "guitars.fill",  // Country Bear Musical Jamboree
        6699: "crown.fill",  // Meet Princess Tiana and a Visiting Princess at Princess Fairytale Hall
        6700: "crown.fill",  // Meet Cinderella and a Visiting Princess at Princess Fairytale Hall
        11527: "bolt.fill",  // TRON Lightcycle / Run
        13630: "drop.triangle.fill",  // Tiana's Bayou Adventure
        13763: "crown.fill",  // Cinderella Castle
        13764: "drop.circle.fill",  // Casey Jr. Splash 'N' Soak Station

        // ─── EPCOT ───
        151: "paperplane.fill",  // Soarin' Around the World
        152: "tortoise.fill",  // Turtle Talk With Crush
        153: "fish.fill",  // The Seas with Nemo & Friends
        155: "lightbulb.fill",  // Journey Into Imagination With Figment
        156: "leaf.fill",  // Living with the Land
        158: "rocket.fill",  // Mission: SPACE
        159: "globe",  // Spaceship Earth
        160: "car.2.fill",  // Test Track
        466: "sailboat.fill",  // Gran Fiesta Tour Starring The Three Caballeros
        829: "film.fill",  // Canada Far and Wide in Circle-Vision 360
        2495: "film.stack.fill",  // Disney and Pixar Short Film Festival
        2679: "snowflake",  // Frozen Ever After
        6701: "snowflake.circle.fill",  // Meet Anna and Elsa at Royal Sommerhus
        7323: "globe.americas.fill",  // Awesome Planet
        10900: "car.2.fill",  // Test Track Single Rider
        10914: "fork.knife",  // Remy's Ratatouille Adventure
        10915: "fork.knife",  // Remy's Ratatouille Adventure Single Rider
        10916: "sparkles.rectangle.stack.fill",  // Guardians of the Galaxy: Cosmic Rewind
        12387: "drop.fill",  // Journey of Water, Inspired by Moana
        13627: "person.2.fill",  // Meet Beloved Disney Pals at Mickey & Friends
        13767: "leaf.circle.fill",  // House of the Whispering Willows
        13770: "fish.circle.fill",  // Bruce's Shark World
        13772: "photo.artframe",  // Gallery of Arts and History
        13773: "flag.fill",  // American Heritage Gallery
        13774: "cpu",  // Advanced Training Lab
        13775: "cpu.fill",  // Project Tomorrow: Inventing the Wonders of the Future
        13776: "building.2.fill",  // Stave Church Gallery
        13777: "paintpalette.fill",  // ImageWorks - The "What If" Labs
        13778: "pencil.and.scribble",  // Kidcot Fun Stops
        13779: "film.circle.fill",  // Palais du Cinéma
        13780: "paintbrush.fill",  // Mexico Folk Art Gallery
        13781: "paintpalette",  // Bijutsu-kan Gallery
        13782: "fish",  // SeaBase Aquarium

        // ─── HOLLYWOOD STUDIOS ───
        117: "scope",  // Toy Story Mania!
        119: "music.note",  // Rock 'n' Roller Coaster Starring The Muppets
        120: "airplane.departure",  // Star Tours – The Adventures Continue
        123: "building.2.fill",  // The Twilight Zone Tower of Terror
        1174: "snowflake",  // For the First Time in Forever: A Frozen Sing-Along Celebration
        1176: "rose.fill",  // Beauty and the Beast – Live on Stage
        5145: "photo.stack.fill",  // Walt Disney Presents
        5476: "dog.fill",  // Slinky Dog Dash
        5477: "circle.hexagongrid.fill",  // Alien Swirling Saucers
        6361: "star.circle.fill",  // Mickey & Minnie's Runaway Railway
        6368: "airplane",  // Millennium Falcon: Smugglers Run
        6369: "star.circle",  // Star Wars: Rise of the Resistance
        6702: "flame.fill",  // Indiana Jones Epic Stunt Spectacular!
        6703: "snowflake",  // Meet Olaf at Celebrity Spotlight
        6704: "camera.fill",  // Meet Disney Stars at Red Carpet Dreams
        7333: "film.stack",  // Vacation Fun - An Original Animated Short with Mickey & Minnie
        10901: "music.note",  // Rock 'n' Roller Coaster Starring The Muppets Single Rider
        10902: "airplane",  // Millennium Falcon: Smugglers Run Single Rider
        12425: "eyeglasses",  // Meet Edna Mode at the Edna Mode Experience
        12430: "fish",  // Meet Ariel at Walt Disney Presents
        14531: "star.circle",  // Star Wars: Rise of the Resistance Single Rider
        14859: "music.mic",  // The Little Mermaid – A Musical Adventure

        // ─── ANIMAL KINGDOM ───
        110: "mountain.2.fill",  // Expedition Everest - Legend of the Forbidden Mountain
        112: "drop.fill",  // Kali River Rapids
        113: "tortoise",  // Kilimanjaro Safaris
        116: "hand.wave.fill",  // Meet Favorite Disney Pals at Adventurers Outpost
        651: "leaf.arrow.circlepath",  // Gorilla Falls Exploration Trail
        655: "tram.fill",  // Wildlife Express Train
        657: "crown",  // Festival of the Lion King
        4438: "moon.stars",  // Na'vi River Journey
        4439: "airplane.departure",  // Avatar Flight of Passage
        10920: "fish.circle.fill",  // Finding Nemo: The Big Blue... and Beyond!
        10921: "bird.fill",  // Feathered Friends in Flight!
        12451: "sailboat.fill",  // Meet Moana at Character Landing
        13751: "tree.fill",  // Tree of Life
        13806: "pawprint.fill",  // Animal Care at Conservation Station
        13807: "pawprint",  // Affection Section
        13808: "figure.hiking",  // Wilderness Explorers
        13811: "figure.walk.motion",  // Discovery Island Trails
        13812: "tree.circle.fill",  // The Oasis Exhibits
        14533: "mountain.2.fill",  // Expedition Everest - Legend of the Forbidden Mountain Single Rider
        14943: "pawprint.circle.fill",  // Zootopia: Better Zoogether!

        // ─── ISLANDS OF ADVENTURE ───
        5985: "circle.grid.cross.fill",  // The Amazing Adventures of Spider-Man
        5986: "figure.equestrian.sports",  // Caro-Seuss-el
        5987: "cat.circle.fill",  // The Cat in The Hat
        5988: "arrow.up.and.down.circle.fill",  // Doctor Doom's Fearfall
        5989: "drop.fill",  // Dudley Do-Right's Ripsaw Falls
        5991: "bird",  // Flight of the Hippogriff
        5992: "book.closed.fill",  // Harry Potter and the Forbidden Journey
        5994: "drop.circle.fill",  // Jurassic Park River Adventure
        5997: "fish.fill",  // One Fish, Two Fish, Red Fish, Blue Fish
        5998: "ferry",  // Popeye & Bluto's Bilge-Rat Barges
        5999: "bird.fill",  // Pteranodon Flyers
        6001: "tram.fill",  // The High in the Sky Seuss Trolley Train Ride!
        6003: "tornado",  // Storm Force Accelatron
        6004: "bolt.circle.fill",  // The Incredible Hulk Coaster
        6008: "figure.climbing",  // Camp Jurassic
        6011: "pawprint",  // If I Ran The Zoo
        6012: "building.2.fill",  // Jurassic Park Discovery Center
        6013: "ferry.fill",  // Me Ship, The Olive
        6015: "tram.fill",  // Hogwarts Express - Hogsmeade Station
        6017: "figure.arms.open",  // Skull Island: Reign of Kong
        6682: "bicycle",  // Hagrid's Magical Creatures Motorbike Adventure
        8721: "pawprint.fill",  // Jurassic World VelociCoaster
        13098: "wand.and.stars",  // Ollivanders Experience in Hogsmeade
        13113: "book.closed.fill",  // Harry Potter and the Forbidden Journey Single Rider
        15384: "bolt.circle.fill",  // The Incredible Hulk Coaster Single Rider
        15403: "bicycle",  // Hagrid's Magical Creatures Motorbike Adventure Single Rider
        15411: "circle.grid.cross.fill",  // The Amazing Adventures of Spider-Man Single Rider

        // ─── UNIVERSAL STUDIOS FLORIDA ───
        5984: "eye.circle.fill",  // Despicable Me Minion Mayhem
        5990: "bicycle",  // E.T. Adventure
        5993: "music.note.list",  // Hollywood Rip Ride Rockit
        5995: "fork.knife.circle.fill",  // Kang & Kodos' Twirl 'n' Hurl
        5996: "scope",  // MEN IN BLACK Alien Attack!
        6000: "pyramid.fill",  // Revenge of the Mummy
        6005: "smiley.fill",  // The Simpsons Ride
        6006: "gearshape.arrow.triangle.2.circlepath",  // TRANSFORMERS: The Ride-3D
        6014: "cart.fill",  // Harry Potter and the Escape from Gringotts
        6016: "tram.fill",  // Hogwarts Express - King's Cross Station
        6018: "building.2.crop.circle.fill",  // Race Through New York Starring Jimmy Fallon
        6038: "car.2.fill",  // Fast & Furious - Supercharged
        12107: "scope",  // Illumination's Villain-Con Minion Blast
        12186: "theatermasks",  // Illumination Theater
        13100: "wand.and.stars",  // Ollivanders Experience in Diagon Alley
        13110: "pyramid.fill",  // Revenge of the Mummy Single Rider
        13605: "music.quarternote.3",  // Trolls Trollercoaster
        13849: "tram.fill",  // Hogwarts Express - First Train
        14517: "scope",  // MEN IN BLACK Alien Attack! Single Rider
        14866: "car.2.fill",  // Fast & Furious - Supercharged Single Rider
        15416: "cart.fill",  // Harry Potter and the Escape from Gringotts Single Rider

        // ─── EPIC UNIVERSE ───
        14682: "target",  // Bowser Jr. Challenge
        14683: "steeringwheel",  // Mario Kart: Bowser's Challenge
        14684: "steeringwheel",  // Mario Kart: Bowser's Challenge Single Rider
        14685: "pawprint.fill",  // Meet Toothless and Friends
        14686: "hammer.circle.fill",  // Mine-Cart Madness
        14687: "wand.and.stars.inverse",  // Harry Potter and the Battle at the Ministry
        14688: "sparkles",  // Constellation Carousel
        14689: "leaf.fill",  // Yoshi's Adventure
        14690: "sparkle.magnifyingglass",  // Stardust Racers
        14691: "drop.fill",  // Fyre Drill
        14692: "moon.stars.fill",  // Curse of the Werewolf
        14693: "flame",  // Dragon Racer's Rally
        14694: "flame.fill",  // Monsters Unchained: The Frankenstein Experiment
        14695: "airplane",  // Hiccup Wing Glider
        14696: "wand.and.stars.inverse",  // Harry Potter and the Battle at the Ministry Single Rider
        14697: "hammer.circle.fill",  // Mine-Cart Madness Single Rider
        14698: "moon.stars.fill",  // Curse of the Werewolf Single Rider
        14699: "flame.fill",  // Monsters Unchained: The Frankenstein Experiment Single Rider
        14740: "sparkle.magnifyingglass",  // Stardust Racers Single Rider

    ]

    /// Returns the best SF Symbol for an attraction: per-ID override if
    /// present, otherwise the type-based fallback.
    static func symbol(for attractionId: Int, type: String?) -> String {
        if let override = attractionSymbolOverrides[attractionId] {
            return override
        }
        return getSFSymbol(for: type)
    }

    /// Generic type-based fallback for attractions that don't have a
    /// thematic override in `attractionSymbolOverrides`.
    static func getSFSymbol(for attractionType: String?) -> String {
        guard let type = attractionType?.lowercased() else { return "questionmark.circle.fill" }
        switch type {
            case "coaster":
                return "train.side.front.car"
            case "water", "drop":
                return "drop.fill"
            case "boat", "safari":
                return "ferry.fill"
            case "darkride", "simulator":
                return "moon.stars.fill"
            case "spinner", "carousel":
                return "circle.grid.3x3.fill"
            case "shooter":
                return "target"
            case "show":
                return "theatermasks.fill"
            case "meet":
                return "person.2.fill"
            case "experience":
                return "figure.walk"
            case "train":
                return "tram.fill"
            case "car":
                return "car.fill"
            default:
                return "questionmark.circle.fill"
        }
    }

    // MARK: - Static Attractions JSON
    //
    // IDs verified against queue-times.com on 2026-05-09. Heights cross-checked
    // against current park published height requirements. Coordinates are
    // approximate centroids for each attraction.
    //
    private static let attractionsJSON = """
    [
    {"id": 1184, "parkId": 6, "name": "A Pirate's Adventure ~ Treasures of the Seven Seas", "type": "experience", "description": "Interactive treasure hunt through Adventureland.", "minHeight": null, "latitude": 28.4183725, "longitude": -81.584669, "tpwUuid": "de737ffc-306b-4f32-8bbb-34e5d370ec8f"},
    {"id": 134, "parkId": 6, "name": "Jungle Cruise", "type": "boat", "description": "A guided tour down the rivers of the world with skipper humor.", "minHeight": null, "latitude": 28.41797818, "longitude": -81.5834393157, "tpwUuid": "796b0a25-c51e-456e-9bb8-50a324e301b3"},
    {"id": 137, "parkId": 6, "name": "Pirates of the Caribbean", "type": "boat", "description": "Set sail on a swashbuckling voyage through pirate-infested waters.", "minHeight": null, "latitude": 28.4179699235, "longitude": -81.5842252029, "tpwUuid": "352feb94-e52e-45eb-9c92-e4b44c6b1a9d"},
    {"id": 355, "parkId": 6, "name": "Swiss Family Treehouse", "type": "experience", "description": "Climb and explore the iconic shipwrecked-family treehouse.", "minHeight": null, "latitude": 28.4184325517, "longitude": -81.5827982677, "tpwUuid": "30fe3c64-af71-4c66-a54b-aa61fd7af177"},
    {"id": 141, "parkId": 6, "name": "The Magic Carpets of Aladdin", "type": "spinner", "description": "Soar high above Adventureland on a flying magic carpet.", "minHeight": null, "latitude": 28.41843, "longitude": -81.583472, "tpwUuid": "96455de6-f4f1-403c-9391-bf8396979149"},
    {"id": 334, "parkId": 6, "name": "Walt Disney's Enchanted Tiki Room", "type": "show", "description": "Tropical birds and flowers come to life in this classic musical show.", "minHeight": null, "latitude": 28.4182264646, "longitude": -81.583738382, "tpwUuid": "6fd1e225-53a0-4a80-a577-4bbc9a471075"},
    {"id": 133, "parkId": 6, "name": "\\\"it's a small world\\\"", "type": "boat", "description": "Take a gentle boat tour and sing along with dolls from around the globe.", "minHeight": null, "latitude": 28.4204816402, "longitude": -81.5820392026, "tpwUuid": "f5aad2d4-a419-4384-bd9a-42f86385c750"},
    {"id": 13764, "parkId": 6, "name": "Casey Jr. Splash 'N' Soak Station", "type": "experience", "description": "Water play area for kids in Storybook Circus.", "minHeight": null, "latitude": 28.4209221723, "longitude": -81.5786757124, "tpwUuid": "f010bc01-b450-4476-a5f3-a5f2813104b2"},
    {"id": 13763, "parkId": 6, "name": "Cinderella Castle", "type": "experience", "description": "Iconic castle and photo opportunity at the heart of the park.", "minHeight": null, "latitude": 28.4194549043, "longitude": -81.5811809, "tpwUuid": "90d79335-c907-4069-a021-d0fe1ec73ae2"},
    {"id": 132, "parkId": 6, "name": "Dumbo the Flying Elephant", "type": "spinner", "description": "Fly high above Storybook Circus on the classic family attraction.", "minHeight": null, "latitude": 28.420509033, "longitude": -81.5789473057, "tpwUuid": "890fa430-89c0-4a3f-96c9-11597888005e"},
    {"id": 128, "parkId": 6, "name": "Enchanted Tales with Belle", "type": "show", "description": "Step into a heartwarming story with Belle and Lumiere.", "minHeight": null, "latitude": 28.4209906, "longitude": -81.58093, "tpwUuid": "e76c93df-31af-49a5-8e2f-752c76c937c9"},
    {"id": 135, "parkId": 6, "name": "Mad Tea Party", "type": "spinner", "description": "Spin in a giant teacup at the Queen of Hearts' unbirthday party.", "minHeight": null, "latitude": 28.4200230397, "longitude": -81.5798248916, "tpwUuid": "0aae716c-af13-4439-b638-d75fb1649df3"},
    {"id": 147, "parkId": 6, "name": "Meet Ariel at Her Grotto", "type": "meet", "description": "Meet Ariel in her undersea grotto.", "minHeight": null, "latitude": 28.4208933, "longitude": -81.579613, "tpwUuid": "012a211b-4c91-451c-8a0e-5e3ab398eda8"},
    {"id": 6700, "parkId": 6, "name": "Meet Cinderella and a Visiting Princess at Princess Fairytale Hall", "type": "meet", "description": "Meet Cinderella and a visiting princess.", "minHeight": null, "latitude": 28.420071, "longitude": -81.580893, "tpwUuid": "40737d3d-0ff6-4a9e-a050-beb87bf90120"},
    {"id": 6699, "parkId": 6, "name": "Meet Princess Tiana and a Visiting Princess at Princess Fairytale Hall", "type": "meet", "description": "Meet Princess Tiana and a visiting princess.", "minHeight": null, "latitude": 28.4200458, "longitude": -81.580917, "tpwUuid": "cf4b2ba4-3626-4de7-9d07-abe8a65b1665"},
    {"id": 171, "parkId": 6, "name": "Mickey's PhilharMagic", "type": "show", "description": "A 4D film extravaganza starring Donald Duck and Disney favorites.", "minHeight": null, "latitude": 28.4200304909, "longitude": -81.5814839853, "tpwUuid": "7c5e1e02-3a44-4151-9005-44066d5ba1da"},
    {"id": 136, "parkId": 6, "name": "Peter Pan's Flight", "type": "darkride", "description": "Soar through London skies to Never Land in a flying pirate galleon.", "minHeight": null, "latitude": 28.4202640272, "longitude": -81.5818916811, "tpwUuid": "86a41273-5f15-4b54-93b6-829f140e5161"},
    {"id": 161, "parkId": 6, "name": "Prince Charming Regal Carrousel", "type": "carousel", "description": "Ride a hand-carved wooden horse on a classic carousel.", "minHeight": null, "latitude": 28.420169, "longitude": -81.581255, "tpwUuid": "273ddb8d-e7b5-4e34-8657-1113f49262a5"},
    {"id": 129, "parkId": 6, "name": "Seven Dwarfs Mine Train", "type": "coaster", "description": "Embark on a swinging coaster ride to retrieve diamonds with the Seven Dwarfs.", "minHeight": 38, "latitude": 28.42037, "longitude": -81.58031, "tpwUuid": "9d4d5229-7142-44b6-b4fb-528920969a2c"},
    {"id": 126, "parkId": 6, "name": "The Barnstormer", "type": "coaster", "description": "Join the Great Goofini on a junior roller coaster.", "minHeight": 35, "latitude": 28.4207661576, "longitude": -81.5783907473, "tpwUuid": "924a3b2c-6b4b-49e5-99d3-e9dc3f2e8a48"},
    {"id": 142, "parkId": 6, "name": "The Many Adventures of Winnie the Pooh", "type": "darkride", "description": "Journey through the Hundred-Acre Wood in a giant Hunny Pot.", "minHeight": null, "latitude": 28.420212, "longitude": -81.580266, "tpwUuid": "0d94ad60-72f0-4551-83a6-ebaecdd89737"},
    {"id": 127, "parkId": 6, "name": "Under the Sea - Journey of The Little Mermaid", "type": "darkride", "description": "Travel under the sea with Ariel and her friends.", "minHeight": null, "latitude": 28.4211203226, "longitude": -81.5799752427, "tpwUuid": "3cba0cb4-e2a6-402c-93ee-c11ffcb127ef"},
    {"id": 1181, "parkId": 6, "name": "Walt Disney World Railroad - Fantasyland", "type": "train", "description": "Board an authentic steam-powered train at the Storybook Circus station.", "minHeight": null, "latitude": 28.420934, "longitude": -81.578368, "tpwUuid": "e40ac396-cbac-43f4-8752-764ed60ccceb"},
    {"id": 130, "parkId": 6, "name": "Big Thunder Mountain Railroad", "type": "coaster", "description": "The wildest ride in the wilderness - now with the new Rainbow Caverns scene.", "minHeight": 38, "latitude": 28.4199638504, "longitude": -81.5846422864, "tpwUuid": "de3309ca-97d5-4211-bffe-739fed47e92f"},
    {"id": 1214, "parkId": 6, "name": "Country Bear Musical Jamboree", "type": "show", "description": "A comical concert featuring a cast of singing animatronic bears.", "minHeight": null, "latitude": 28.4187861348, "longitude": -81.5837222887, "tpwUuid": "0f57cecf-5502-4503-8bc3-ba84d3708ace"},
    {"id": 13630, "parkId": 6, "name": "Tiana's Bayou Adventure", "type": "water", "description": "Float through a vibrant bayou celebration with Princess Tiana.", "minHeight": 40, "latitude": 28.419418, "longitude": -81.58498, "tpwUuid": "73cb9445-0695-47a3-87ce-d08ae36b5f3c"},
    {"id": 140, "parkId": 6, "name": "Haunted Mansion", "type": "darkride", "description": "Climb aboard a Doom Buggy for a tour of a haunted estate.", "minHeight": null, "latitude": 28.4202, "longitude": -81.58288, "tpwUuid": "2551a77d-023f-4ab1-9a19-8afec0190f39"},
    {"id": 356, "parkId": 6, "name": "The Hall of Presidents", "type": "show", "description": "Behold all U.S. Presidents in a stirring Audio-Animatronics show.", "minHeight": null, "latitude": 28.4194484171, "longitude": -81.5823248578, "tpwUuid": "2ebfb38c-5cb5-4de1-86c0-f7af14188022"},
    {"id": 1188, "parkId": 6, "name": "Main Street Vehicles", "type": "car", "description": "Ride a classic vehicle down Main Street, U.S.A.", "minHeight": null, "latitude": 28.4168698711, "longitude": -81.5815081252, "tpwUuid": "888fb4a4-7adf-47a1-8ba2-c258cc64fd75"},
    {"id": 146, "parkId": 6, "name": "Meet Mickey at Town Square Theater", "type": "meet", "description": "Meet Mickey Mouse at Town Square Theater.", "minHeight": null, "latitude": 28.416727, "longitude": -81.580746, "tpwUuid": "a2d92647-634d-4eb4-886b-9da858e871f1"},
    {"id": 1189, "parkId": 6, "name": "Walt Disney World Railroad - Main Street, U.S.A.", "type": "train", "description": "Board the steam-powered grand circle tour at the Main Street station.", "minHeight": null, "latitude": 28.416543, "longitude": -81.581204, "tpwUuid": "e39b831b-7731-49bb-815b-289b4f49a9fd"},
    {"id": 248, "parkId": 6, "name": "Astro Orbiter", "type": "spinner", "description": "Pilot your own spaceship high above Tomorrowland.", "minHeight": null, "latitude": 28.4184926179, "longitude": -81.5789887902, "tpwUuid": "d9d12438-d999-4482-894b-8955fdb20ccf"},
    {"id": 131, "parkId": 6, "name": "Buzz Lightyear's Space Ranger Spin", "type": "shooter", "description": "Reopened April 2026 with new ride vehicles, blasters, and a new character - help Buzz defeat Zurg.", "minHeight": null, "latitude": 28.4182868839, "longitude": -81.5794086456, "tpwUuid": "72c7343a-f7fb-4f66-95df-c91016de7338"},
    {"id": 125, "parkId": 6, "name": "Monsters Inc. Laugh Floor", "type": "show", "description": "Enjoy interactive comedy with Mike Wazowski and the monsters.", "minHeight": null, "latitude": 28.4183977566, "longitude": -81.5797358751, "tpwUuid": "e8f0b426-7645-4ea3-8b41-b94ae7091a41"},
    {"id": 138, "parkId": 6, "name": "Space Mountain", "type": "coaster", "description": "Blast off on a high-speed adventure through deep space in the dark.", "minHeight": 44, "latitude": 28.4188341691, "longitude": -81.5781962872, "tpwUuid": "b2260923-9315-40fd-9c6b-44dd811dbe64"},
    {"id": 143, "parkId": 6, "name": "Tomorrowland Speedway", "type": "car", "description": "Take the wheel of a gas-powered car along a miniature motorway.", "minHeight": 32, "latitude": 28.419368, "longitude": -81.579302, "tpwUuid": "f163ddcd-43e1-488d-8276-2381c1db0a39"},
    {"id": 1190, "parkId": 6, "name": "Tomorrowland Transit Authority PeopleMover", "type": "experience", "description": "A slow-moving narrated tour of Tomorrowland.", "minHeight": null, "latitude": 28.418155, "longitude": -81.579033, "tpwUuid": "ffcfeaa2-1416-4920-a1ed-543c1a1695c4"},
    {"id": 11527, "parkId": 6, "name": "TRON Lightcycle / Run", "type": "coaster", "description": "Race through the Grid on a thrilling motorcycle-style coaster.", "minHeight": 48, "latitude": 28.419625, "longitude": -81.577985, "tpwUuid": "5a43d1a7-ad53-4d25-abfe-25625f0da304"},
    {"id": 457, "parkId": 6, "name": "Walt Disney's Carousel of Progress", "type": "show", "description": "Revolve through the 20th century with a classic American family.", "minHeight": null, "latitude": 28.4180310951, "longitude": -81.5790083064, "tpwUuid": "8183f3f2-1b59-4b9c-b634-6a863bdf8d84"},
    {"id": 159, "parkId": 5, "name": "Spaceship Earth", "type": "darkride", "description": "An inspiring dark ride through the history of communication inside the icon.", "minHeight": null, "latitude": 28.375583, "longitude": -81.549401, "tpwUuid": "480fde8f-fe58-4bfb-b3ab-052a39d4db7c"},
    {"id": 13627, "parkId": 5, "name": "Meet Beloved Disney Pals at Mickey & Friends", "type": "meet", "description": "Meet Mickey, Minnie, and friends in World Celebration.", "minHeight": null, "latitude": 28.373898, "longitude": -81.549914, "tpwUuid": "67612787-fbd3-44b7-869f-123f55d78584"},
    {"id": 13775, "parkId": 5, "name": "Project Tomorrow: Inventing the Wonders of the Future", "type": "experience", "description": "Interactive post-show after Spaceship Earth with future-tech exhibits.", "minHeight": null, "latitude": 28.37476, "longitude": -81.549401, "tpwUuid": "9053240b-7f7f-44fe-970b-bd7956cd5d4f"},
    {"id": 158, "parkId": 5, "name": "Mission: SPACE", "type": "simulator", "description": "Train for a mission to Mars - choose Green (mild) or Orange (intense).", "minHeight": 40, "latitude": 28.373927, "longitude": -81.547156, "tpwUuid": "5b6475ad-4e9a-4793-b841-501aa382c9c0"},
    {"id": 160, "parkId": 5, "name": "Test Track", "type": "coaster", "description": "Reopened version of the Test Track ride. Design a virtual concept car and take it for a high-speed spin.", "minHeight": 40, "latitude": 28.373228, "longitude": -81.547489, "tpwUuid": "37ae57c5-feaf-4e47-8f27-4b385be200f0"},
    {"id": 10900, "parkId": 5, "name": "Test Track Single Rider", "type": "coaster", "description": "Single rider line for Test Track.", "minHeight": 40, "latitude": 28.373228, "longitude": -81.547489, "tpwUuid": "37ae57c5-feaf-4e47-8f27-4b385be200f0"},
    {"id": 10916, "parkId": 5, "name": "Guardians of the Galaxy: Cosmic Rewind", "type": "coaster", "description": "An indoor reverse-launch coaster with rotating cars and a Marvel storyline.", "minHeight": 42, "latitude": 28.3749021961781, "longitude": -81.5478397673417, "tpwUuid": "e3549451-b284-453d-9c31-e3b1207abd79"},
    {"id": 13774, "parkId": 5, "name": "Advanced Training Lab", "type": "experience", "description": "Interactive space-themed play area at Mission: SPACE.", "minHeight": null, "latitude": 28.374185, "longitude": -81.547072, "tpwUuid": "3d8f8f8f-f984-4d2e-8dea-5a79432bdf05"},
    {"id": 151, "parkId": 5, "name": "Soarin' Around the World", "type": "simulator", "description": "Soar over global landmarks on a hang-gliding simulator.", "minHeight": 40, "latitude": 28.373592, "longitude": -81.552248, "tpwUuid": "81b15dfd-cf6a-466f-be59-3dd65d2a2807"},
    {"id": 152, "parkId": 5, "name": "Turtle Talk With Crush", "type": "show", "description": "Interactive real-time conversation with Crush the sea turtle.", "minHeight": null, "latitude": 28.375255, "longitude": -81.551047, "tpwUuid": "57acb522-a6fc-4aa4-a80e-21f21f317250"},
    {"id": 153, "parkId": 5, "name": "The Seas with Nemo & Friends", "type": "darkride", "description": "Board a clammobile and journey under the sea with Nemo and Dory.", "minHeight": null, "latitude": 28.374904, "longitude": -81.550852, "tpwUuid": "fb076275-0570-4d62-b2a9-4d6515130fa3"},
    {"id": 155, "parkId": 5, "name": "Journey Into Imagination With Figment", "type": "darkride", "description": "A whimsical dark ride through your imagination with Figment.", "minHeight": null, "latitude": 28.372994, "longitude": -81.551401, "tpwUuid": "75449e85-c410-4cef-a368-9d2ea5d52b58"},
    {"id": 156, "parkId": 5, "name": "Living with the Land", "type": "boat", "description": "Sail through working greenhouses growing real produce served at EPCOT.", "minHeight": null, "latitude": 28.374245, "longitude": -81.552301, "tpwUuid": "8f353879-d6ac-4211-9352-4029efb47c18"},
    {"id": 2495, "parkId": 5, "name": "Disney and Pixar Short Film Festival", "type": "show", "description": "A 4D theater festival featuring Disney and Pixar shorts.", "minHeight": null, "latitude": 28.37263, "longitude": -81.55115, "tpwUuid": "35ed719b-f7f0-488f-8346-4fbf8055d373"},
    {"id": 7323, "parkId": 5, "name": "Awesome Planet", "type": "show", "description": "A film celebrating Earth's beauty and the importance of conservation.", "minHeight": null, "latitude": 28.374301, "longitude": -81.552138, "tpwUuid": "482169b9-2889-4747-8aef-f9d13a37d940"},
    {"id": 12387, "parkId": 5, "name": "Journey of Water, Inspired by Moana", "type": "experience", "description": "Interactive outdoor walking trail tracing the water cycle.", "minHeight": null, "latitude": 28.374691, "longitude": -81.550378, "tpwUuid": "dae68dee-dfba-4128-b594-6aa12add1070"},
    {"id": 13770, "parkId": 5, "name": "Bruce's Shark World", "type": "experience", "description": "Interactive play area near The Seas pavilion.", "minHeight": null, "latitude": 28.375099, "longitude": -81.551245451, "tpwUuid": "2ecc4fff-2994-476f-9926-24a4af173838"},
    {"id": 13777, "parkId": 5, "name": "ImageWorks - The \\\"What If\\\" Labs", "type": "experience", "description": "Interactive play area in the Imagination! pavilion.", "minHeight": null, "latitude": 28.372774, "longitude": -81.551121, "tpwUuid": "3e5f26ee-c02d-47fd-891e-5e4479073444"},
    {"id": 13782, "parkId": 5, "name": "SeaBase Aquarium", "type": "experience", "description": "Explore one of the largest saltwater aquariums in North America.", "minHeight": null, "latitude": 28.375098, "longitude": -81.551211, "tpwUuid": "7969166f-feef-4350-b26e-6a6c745528f4"},
    {"id": 466, "parkId": 5, "name": "Gran Fiesta Tour Starring The Three Caballeros", "type": "boat", "description": "A gentle boat ride through Mexico with Donald Duck.", "minHeight": null, "latitude": 28.371649, "longitude": -81.547368, "tpwUuid": "22f48b73-01df-460e-8969-9eb2b4ae836c"},
    {"id": 829, "parkId": 5, "name": "Canada Far and Wide in Circle-Vision 360", "type": "show", "description": "A 360-degree film showcasing the beauty of Canada.", "minHeight": null, "latitude": 28.371694, "longitude": -81.55196, "tpwUuid": "61fb49f8-e62f-4e1c-ae0e-8ab9929037bc"},
    {"id": 2679, "parkId": 5, "name": "Frozen Ever After", "type": "boat", "description": "A musical boat ride through Arendelle - now with new fully-sculpted Anna, Elsa, and Kristoff animatronics (Feb 2026).", "minHeight": null, "latitude": 28.370745, "longitude": -81.54653, "tpwUuid": "8d7ccdb1-a22b-4e26-8dc8-65b1938ed5f0"},
    {"id": 6701, "parkId": 5, "name": "Meet Anna and Elsa at Royal Sommerhus", "type": "meet", "description": "Meet Anna and Elsa in the Norway Pavilion.", "minHeight": null, "latitude": 28.37097, "longitude": -81.547134, "tpwUuid": "33bd3bad-6803-4c5e-97ac-f7e31261a604"},
    {"id": 10914, "parkId": 5, "name": "Remy's Ratatouille Adventure", "type": "darkride", "description": "Shrink to the size of a rat for a 4D culinary chase through Paris.", "minHeight": null, "latitude": 28.36825, "longitude": -81.553097, "tpwUuid": "1e735ffb-4868-47f1-b2cd-2ac1156cd5f0"},
    {"id": 10915, "parkId": 5, "name": "Remy's Ratatouille Adventure Single Rider", "type": "darkride", "description": "Single rider line for Remy's Ratatouille Adventure.", "minHeight": null, "latitude": 28.36825, "longitude": -81.553097, "tpwUuid": "1e735ffb-4868-47f1-b2cd-2ac1156cd5f0"},
    {"id": 13767, "parkId": 5, "name": "House of the Whispering Willows", "type": "show", "description": "Chinese art and culture exhibits in the China pavilion.", "minHeight": null, "latitude": 28.36999, "longitude": -81.546334, "tpwUuid": "0f40274d-420a-425a-9377-29fd6e49484f"},
    {"id": 13772, "parkId": 5, "name": "Gallery of Arts and History", "type": "show", "description": "Cultural exhibits in the Morocco pavilion.", "minHeight": null, "latitude": 28.368236, "longitude": -81.551612, "tpwUuid": "07dbeaea-85fa-45f2-872f-02f9e7510419"},
    {"id": 13773, "parkId": 5, "name": "American Heritage Gallery", "type": "show", "description": "American history and culture exhibits at the American Adventure pavilion.", "minHeight": null, "latitude": 28.367517, "longitude": -81.549469, "tpwUuid": "4f0df9e7-d4c1-45b5-93e2-4a7bc92547b0"},
    {"id": 13776, "parkId": 5, "name": "Stave Church Gallery", "type": "show", "description": "Norwegian culture and history exhibits in the Norway pavilion.", "minHeight": null, "latitude": 28.370621, "longitude": -81.546971, "tpwUuid": "66ff36de-9cb3-4d9a-b891-1665d19ffb3e"},
    {"id": 13778, "parkId": 5, "name": "Kidcot Fun Stops", "type": "experience", "description": "Interactive craft stations for kids throughout World Showcase.", "minHeight": null, "latitude": 28.3718643, "longitude": -81.551537, "tpwUuid": "3ace01d1-15fc-4fbb-99e4-81a696cb2d05"},
    {"id": 13779, "parkId": 5, "name": "Palais du Cinema", "type": "show", "description": "French cinema short film in the France pavilion.", "minHeight": null, "latitude": 28.368864, "longitude": -81.552978, "tpwUuid": "18c533d6-a395-4ae4-9488-80fce9c497fe"},
    {"id": 13780, "parkId": 5, "name": "Mexico Folk Art Gallery", "type": "show", "description": "Mexican folk art exhibits inside the Mexico pyramid.", "minHeight": null, "latitude": 28.371511, "longitude": -81.54746, "tpwUuid": "8f8746cb-c714-4c60-848d-e2dc4e6f586b"},
    {"id": 13781, "parkId": 5, "name": "Bijutsu-kan Gallery", "type": "show", "description": "Japanese art and culture exhibits in the Japan pavilion.", "minHeight": null, "latitude": 28.367309, "longitude": -81.550525, "tpwUuid": "6f1d3b25-42c9-4e99-9dce-6c20d7a5deea"},
    {"id": 5145, "parkId": 7, "name": "Walt Disney Presents", "type": "show", "description": "Exhibits and short film about Walt Disney's life and legacy.", "minHeight": null, "latitude": 28.35686, "longitude": -81.560982, "tpwUuid": "d7669edc-eaa1-4af2-bbb5-6e98df564166"},
    {"id": 14859, "parkId": 7, "name": "The Little Mermaid - A Musical Adventure", "type": "show", "description": "Live musical retelling of The Little Mermaid with puppetry and effects.", "minHeight": null, "latitude": 28.3574862, "longitude": -81.560848, "tpwUuid": "a7763ca6-bca3-4e78-b75c-22886aa06bec"},
    {"id": 12430, "parkId": 7, "name": "Meet Ariel at Walt Disney Presents", "type": "meet", "description": "Meet Ariel near Walt Disney Presents (limited availability).", "minHeight": null, "latitude": 28.356945, "longitude": -81.560998, "tpwUuid": "c113b1cf-7b6d-416a-8e21-bf8f387ecd77"},
    {"id": 6704, "parkId": 7, "name": "Meet Disney Stars at Red Carpet Dreams", "type": "meet", "description": "Meet rotating Disney characters at the Red Carpet Dreams photo location.", "minHeight": null, "latitude": 28.356068, "longitude": -81.559479, "tpwUuid": "02861a9b-584d-47d5-a8d0-98e05c3b5dce"},
    {"id": 1174, "parkId": 7, "name": "For the First Time in Forever: A Frozen Sing-Along Celebration", "type": "show", "description": "Sing along with Anna, Elsa, and Kristoff in this Frozen-themed show.", "minHeight": null, "latitude": 28.3568243, "longitude": -81.559694, "tpwUuid": "d91a0e9a-8652-4036-822f-e7b12b381273"},
    {"id": 6702, "parkId": 7, "name": "Indiana Jones Epic Stunt Spectacular!", "type": "show", "description": "Live-action stunt show recreating scenes from Raiders of the Lost Ark.", "minHeight": null, "latitude": 28.3566701, "longitude": -81.558611, "tpwUuid": "7357772c-6b11-4a8d-af97-05a1bb45f001"},
    {"id": 6703, "parkId": 7, "name": "Meet Olaf at Celebrity Spotlight", "type": "meet", "description": "Meet Olaf from Frozen.", "minHeight": null, "latitude": 28.356072, "longitude": -81.559158, "tpwUuid": "27f9fc86-2341-4bf4-8cbf-67fc16a841f1"},
    {"id": 120, "parkId": 7, "name": "Star Tours - The Adventures Continue", "type": "simulator", "description": "A 3D motion-simulated space flight to destinations from the Star Wars films.", "minHeight": 40, "latitude": 28.355695, "longitude": -81.558891, "tpwUuid": "3b290419-8ca2-44bc-a710-a6c83fca76ec"},
    {"id": 7333, "parkId": 7, "name": "Vacation Fun - An Original Animated Short with Mickey & Minnie", "type": "show", "description": "Animated short film with Mickey & Minnie.", "minHeight": null, "latitude": 28.356316, "longitude": -81.559031, "tpwUuid": "9211adc9-b296-4667-8e97-b40cf76108e4"},
    {"id": 6361, "parkId": 7, "name": "Mickey & Minnie's Runaway Railway", "type": "darkride", "description": "Step into a Mickey Mouse cartoon on this trackless dark ride.", "minHeight": null, "latitude": 28.3566783801, "longitude": -81.5605667783, "tpwUuid": "6e118e37-5002-408d-9d88-0b5d9cdb5d14"},
    {"id": 12425, "parkId": 7, "name": "Meet Edna Mode at the Edna Mode Experience", "type": "meet", "description": "Meet Edna Mode from The Incredibles.", "minHeight": null, "latitude": 28.356086, "longitude": -81.560742, "tpwUuid": "79860074-658f-49bc-8c1b-624af8b4718e"},
    {"id": 117, "parkId": 7, "name": "Toy Story Mania!", "type": "shooter", "description": "An interactive 4D shooting-gallery ride starring Toy Story characters.", "minHeight": null, "latitude": 28.356404, "longitude": -81.561894, "tpwUuid": "20b5daa8-e1ea-436f-830c-2d7d18d929b5"},
    {"id": 6368, "parkId": 7, "name": "Millennium Falcon: Smugglers Run", "type": "simulator", "description": "Pilot the Millennium Falcon on a thrilling interactive mission - now with new Mandalorian missions (May 2026).", "minHeight": 38, "latitude": 28.353889, "longitude": -81.561689, "tpwUuid": "34c4916b-989b-4ff1-a7e3-a6a846a3484f"},
    {"id": 10902, "parkId": 7, "name": "Millennium Falcon: Smugglers Run Single Rider", "type": "simulator", "description": "Single rider line for Millennium Falcon: Smugglers Run.", "minHeight": 38, "latitude": 28.353889, "longitude": -81.561689, "tpwUuid": "34c4916b-989b-4ff1-a7e3-a6a846a3484f"},
    {"id": 6369, "parkId": 7, "name": "Star Wars: Rise of the Resistance", "type": "darkride", "description": "Join the Resistance in an epic, multi-platform battle against the First Order.", "minHeight": 40, "latitude": 28.354884, "longitude": -81.560457, "tpwUuid": "1a2e70d9-50d5-4140-b69e-799e950f7d18"},
    {"id": 14531, "parkId": 7, "name": "Star Wars: Rise of the Resistance Single Rider", "type": "darkride", "description": "Single rider line for Rise of the Resistance.", "minHeight": 40, "latitude": 28.354884, "longitude": -81.560457, "tpwUuid": "1a2e70d9-50d5-4140-b69e-799e950f7d18"},
    {"id": 1176, "parkId": 7, "name": "Beauty and the Beast - Live on Stage", "type": "show", "description": "Broadway-style stage musical of Beauty and the Beast.", "minHeight": null, "latitude": 28.3589163, "longitude": -81.559599, "tpwUuid": "375197ac-27ac-41f7-bd93-f4e9b9fc4d5d"},
    {"id": 119, "parkId": 7, "name": "Rock 'n' Roller Coaster Starring The Muppets", "type": "coaster", "description": "Reimagined as a Muppets-themed indoor launch coaster (opens May 26, 2026). Same hardware, new theme.", "minHeight": 48, "latitude": 28.359712, "longitude": -81.56059, "tpwUuid": "e516f303-e82d-4fd3-8fbf-8e6ab624cf89"},
    {"id": 10901, "parkId": 7, "name": "Rock 'n' Roller Coaster Starring The Muppets Single Rider", "type": "coaster", "description": "Single rider line for Rock 'n' Roller Coaster Starring The Muppets.", "minHeight": 48, "latitude": 28.359712, "longitude": -81.56059, "tpwUuid": "e516f303-e82d-4fd3-8fbf-8e6ab624cf89"},
    {"id": 123, "parkId": 7, "name": "The Twilight Zone Tower of Terror", "type": "drop", "description": "Plummet 13 stories in a haunted hotel elevator.", "minHeight": 40, "latitude": 28.359553, "longitude": -81.559772, "tpwUuid": "6f6998e8-a629-412c-b964-2cb06af8e26b"},
    {"id": 5477, "parkId": 7, "name": "Alien Swirling Saucers", "type": "spinner", "description": "Spin around in a toy saucer with the Little Green Aliens.", "minHeight": 32, "latitude": 28.355385, "longitude": -81.562379, "tpwUuid": "d56506e2-6ad3-443a-8065-fea37987248d"},
    {"id": 5476, "parkId": 7, "name": "Slinky Dog Dash", "type": "coaster", "description": "A family-friendly coaster that twists through Andy's backyard on Slinky's back.", "minHeight": 38, "latitude": 28.356245, "longitude": -81.562786, "tpwUuid": "399aa0a1-98e2-4d2b-b297-2b451e9665e1"},
    {"id": 657, "parkId": 8, "name": "Festival of the Lion King", "type": "show", "description": "A spectacular Broadway-style show with songs and pageantry from The Lion King.", "minHeight": null, "latitude": 28.35811, "longitude": -81.592643, "tpwUuid": "3a4e0f49-f9ff-4481-a95b-d4952cdf6097"},
    {"id": 651, "parkId": 8, "name": "Gorilla Falls Exploration Trail", "type": "experience", "description": "A walking trail featuring gorillas, hippos, and African wildlife.", "minHeight": null, "latitude": 28.359954, "longitude": -81.592149, "tpwUuid": "e7976e25-4322-4587-8ded-fb1d9dcbb83c"},
    {"id": 113, "parkId": 8, "name": "Kilimanjaro Safaris", "type": "safari", "description": "Climb aboard an open-air vehicle for a guided tour of an African savanna.", "minHeight": null, "latitude": 28.359331, "longitude": -81.59228, "tpwUuid": "32e01181-9a5f-4936-8a77-0dace1de836c"},
    {"id": 655, "parkId": 8, "name": "Wildlife Express Train", "type": "train", "description": "A rustic steam train to Rafiki's Planet Watch.", "minHeight": null, "latitude": 28.3598097347, "longitude": -81.5914175464, "tpwUuid": "4f391f0e-52be-4f9d-99d6-b3ae0373b43c"},
    {"id": 110, "parkId": 8, "name": "Expedition Everest - Legend of the Forbidden Mountain", "type": "coaster", "description": "Race through the Himalayas on a runaway train to escape the Yeti.", "minHeight": 44, "latitude": 28.3584769119, "longitude": -81.5873781396, "tpwUuid": "64a6915f-a835-4226-ba5c-8389fc4cade3"},
    {"id": 14533, "parkId": 8, "name": "Expedition Everest - Legend of the Forbidden Mountain Single Rider", "type": "coaster", "description": "Single rider line for Expedition Everest.", "minHeight": 44, "latitude": 28.3584769119, "longitude": -81.5873781396, "tpwUuid": "64a6915f-a835-4226-ba5c-8389fc4cade3"},
    {"id": 10921, "parkId": 8, "name": "Feathered Friends in Flight!", "type": "show", "description": "Live bird show featuring free-flying parrots and birds of prey.", "minHeight": null, "latitude": 28.358791, "longitude": -81.590061, "tpwUuid": "d8214ba6-22a7-4a92-8977-bae3779d5c4c"},
    {"id": 112, "parkId": 8, "name": "Kali River Rapids", "type": "water", "description": "A whitewater raft adventure through a rainforest - expect to get soaked.", "minHeight": 38, "latitude": 28.3587834288, "longitude": -81.5889412165, "tpwUuid": "d58d9262-ec95-4161-80a0-07ca43b2f5f3"},
    {"id": 10920, "parkId": 8, "name": "Finding Nemo: The Big Blue... and Beyond!", "type": "show", "description": "Musical stage show featuring Nemo, Marlin, and Dory.", "minHeight": null, "latitude": 28.357401, "longitude": -81.587455, "tpwUuid": "95712b31-ceed-4f7d-be3e-3d5e6badac5c"},
    {"id": 13811, "parkId": 8, "name": "Discovery Island Trails", "type": "experience", "description": "Nature trails encircling the Tree of Life.", "minHeight": null, "latitude": 28.3581032852655, "longitude": -81.5911151562868, "tpwUuid": "4d27b0d7-2b0a-4569-90fa-e79f117ec7ef"},
    {"id": 116, "parkId": 8, "name": "Meet Favorite Disney Pals at Adventurers Outpost", "type": "meet", "description": "Meet Mickey and Minnie in their safari gear.", "minHeight": null, "latitude": 28.357972, "longitude": -81.589796, "tpwUuid": "13d7c9d1-a785-403d-9ba8-71fee2f02d55"},
    {"id": 12451, "parkId": 8, "name": "Meet Moana at Character Landing", "type": "meet", "description": "Meet Moana on Discovery Island.", "minHeight": null, "latitude": 28.357086, "longitude": -81.589374, "tpwUuid": "f526f3ab-190b-4576-8c79-e2968d171b4e"},
    {"id": 13751, "parkId": 8, "name": "Tree of Life", "type": "experience", "description": "The iconic 145-foot centerpiece of Animal Kingdom with carved animals.", "minHeight": null, "latitude": 28.357994, "longitude": -81.590597, "tpwUuid": "bc1ffa86-9b1a-4ce9-84a5-b479dfa3cb53"},
    {"id": 14943, "parkId": 8, "name": "Zootopia: Better Zoogether!", "type": "show", "description": "A 4D theater show inside the Tree of Life with Judy Hopps and Nick Wilde (opened Nov 7, 2025).", "minHeight": null, "latitude": 28.357488, "longitude": -81.590118, "tpwUuid": "1b15c77b-0311-4171-8e59-7f38e6d60754"},
    {"id": 4439, "parkId": 8, "name": "Avatar Flight of Passage", "type": "simulator", "description": "Fly on the back of a banshee on a 3D ride over the world of Pandora.", "minHeight": 44, "latitude": 28.355554, "longitude": -81.592147, "tpwUuid": "24cf863c-b6ba-4826-a056-0b698989cbf7"},
    {"id": 4438, "parkId": 8, "name": "Na'vi River Journey", "type": "boat", "description": "A gentle, mystical boat ride through a bioluminescent rainforest.", "minHeight": null, "latitude": 28.355257, "longitude": -81.591641, "tpwUuid": "7a5af3b7-9bc1-4962-92d0-3ea9c9ce35f0"},
    {"id": 13807, "parkId": 8, "name": "Affection Section", "type": "experience", "description": "Petting zoo at Rafiki's Planet Watch.", "minHeight": null, "latitude": 28.3653458262, "longitude": -81.5888520134, "tpwUuid": "a15ce7cf-342a-4c7a-9372-7a1fa1054747"},
    {"id": 13806, "parkId": 8, "name": "Animal Care at Conservation Station", "type": "experience", "description": "Watch real-time animal care, training, and veterinary procedures.", "minHeight": null, "latitude": 28.36533, "longitude": -81.58872, "tpwUuid": "6fbe6d02-4057-43bb-80a3-047b1e8a50ca"},
    {"id": 13812, "parkId": 8, "name": "The Oasis Exhibits", "type": "experience", "description": "Animal exhibits along the lush walking path at the park entrance.", "minHeight": null, "latitude": 28.355965, "longitude": -81.59014, "tpwUuid": "bc997600-fcc0-4f6f-b908-a1419b26cfd8"},
    {"id": 13808, "parkId": 8, "name": "Wilderness Explorers", "type": "experience", "description": "Park-wide interactive scavenger hunt earning badges with Russell from Up.", "minHeight": null, "latitude": 28.356682, "longitude": -81.590292, "tpwUuid": "6ef1b126-5b0b-46a1-8608-4fcf98ab92c8"},
    {"id": 5985, "parkId": 64, "name": "The Amazing Adventures of Spider-Man", "type": "darkride", "description": "A 3D dark ride battling Spider-Man villains across NYC.", "minHeight": 40, "latitude": 28.4705456, "longitude": -81.469852, "tpwUuid": "6be23178-7d00-4884-9e88-76787da1df86"},
    {"id": 15411, "parkId": 64, "name": "The Amazing Adventures of Spider-Man Single Rider", "type": "darkride", "description": "Single rider line for The Amazing Adventures of Spider-Man.", "minHeight": 40, "latitude": 28.4705456, "longitude": -81.469852, "tpwUuid": "6be23178-7d00-4884-9e88-76787da1df86"},
    {"id": 5988, "parkId": 64, "name": "Doctor Doom's Fearfall", "type": "drop", "description": "An intense vertical launch and drop tower.", "minHeight": 52, "latitude": 28.470678, "longitude": -81.469502, "tpwUuid": "2f95b213-daaa-4370-8349-c2cd57be470e"},
    {"id": 6003, "parkId": 64, "name": "Storm Force Accelatron", "type": "spinner", "description": "A spinning carnival ride themed to Storm of the X-Men.", "minHeight": null, "latitude": 28.471007, "longitude": -81.468794, "tpwUuid": "b694d5a5-155e-4796-af7e-5dbdcf3deba4"},
    {"id": 6004, "parkId": 64, "name": "The Incredible Hulk Coaster", "type": "coaster", "description": "Launch from 0 to 40 mph in two seconds and twist through inversions.", "minHeight": 54, "latitude": 28.471257, "longitude": -81.469121, "tpwUuid": "fa743143-281b-4b5b-b87b-d49fcb006772"},
    {"id": 15384, "parkId": 64, "name": "The Incredible Hulk Coaster Single Rider", "type": "coaster", "description": "Single rider line for The Incredible Hulk Coaster.", "minHeight": 54, "latitude": 28.471257, "longitude": -81.469121, "tpwUuid": "fa743143-281b-4b5b-b87b-d49fcb006772"},
    {"id": 5989, "parkId": 64, "name": "Dudley Do-Right's Ripsaw Falls", "type": "water", "description": "A log flume with multiple drops including an 85-foot finale.", "minHeight": 44, "latitude": 28.4695018, "longitude": -81.4714998, "tpwUuid": "905d7888-b866-4e74-90d1-07fc6ef6706f"},
    {"id": 5998, "parkId": 64, "name": "Popeye & Bluto's Bilge-Rat Barges", "type": "water", "description": "Spin and splash through whitewater rapids - guaranteed soaking.", "minHeight": 42, "latitude": 28.470448, "longitude": -81.471401, "tpwUuid": "b4445a1c-4d5c-4fca-a04a-f8867f1b6619"},
    {"id": 6013, "parkId": 64, "name": "Me Ship, The Olive", "type": "experience", "description": "Three-deck play area themed to Popeye's ship.", "minHeight": null, "latitude": 28.4709684, "longitude": -81.4712606, "tpwUuid": "8babd50d-c570-423b-bd53-d040cad3e087"},
    {"id": 5994, "parkId": 64, "name": "Jurassic Park River Adventure", "type": "water", "description": "A water tour with dinosaurs that ends in an 85-foot plunge from the T-rex.", "minHeight": 42, "latitude": 28.470597, "longitude": -81.473134, "tpwUuid": "db5b2165-15c2-4e51-8bd1-611e9c351866"},
    {"id": 5999, "parkId": 64, "name": "Pteranodon Flyers", "type": "spinner", "description": "A suspended glider ride above Jurassic Park (riders must be 36-56 inches).", "minHeight": 36, "latitude": 28.470164, "longitude": -81.472939, "tpwUuid": "3daca54f-50f0-44e9-a993-d706ce7520a0"},
    {"id": 6008, "parkId": 64, "name": "Camp Jurassic", "type": "experience", "description": "A prehistoric-themed playground with caves, slides, and net climbs.", "minHeight": null, "latitude": 28.470134, "longitude": -81.4727356, "tpwUuid": "f6dba1c6-6f5a-4743-8470-f741ecac555d"},
    {"id": 6012, "parkId": 64, "name": "Jurassic Park Discovery Center", "type": "experience", "description": "Interactive exhibits about dinosaurs and the Jurassic Park story.", "minHeight": null, "latitude": 28.4715876, "longitude": -81.4726189, "tpwUuid": "22dcd29e-d76a-45cd-b44a-dd6350dc3f8a"},
    {"id": 6017, "parkId": 64, "name": "Skull Island: Reign of Kong", "type": "darkride", "description": "A 3D dark ride encounter with King Kong.", "minHeight": 36, "latitude": 28.469317, "longitude": -81.473013, "tpwUuid": "370ba4d1-f199-4dc2-be6d-6bb09b442891"},
    {"id": 8721, "parkId": 64, "name": "Jurassic World VelociCoaster", "type": "coaster", "description": "A high-speed launch coaster with a near-vertical 80-degree drop.", "minHeight": 51, "latitude": 28.471429, "longitude": -81.472284, "tpwUuid": "61079a31-4165-4fb0-b36f-c01c5971f80a"},
    {"id": 5991, "parkId": 64, "name": "Flight of the Hippogriff", "type": "coaster", "description": "A family-friendly roller coaster around Hagrid's hut.", "minHeight": 36, "latitude": 28.472416, "longitude": -81.473636, "tpwUuid": "23b613e0-ae83-455b-9163-231bdbd5c427"},
    {"id": 6682, "parkId": 64, "name": "Hagrid's Magical Creatures Motorbike Adventure", "type": "coaster", "description": "Race through the Forbidden Forest on a motorbike or sidecar.", "minHeight": 48, "latitude": 28.47308, "longitude": -81.472862, "tpwUuid": "578bbd12-1975-4ec3-9879-ea641c780342"},
    {"id": 15403, "parkId": 64, "name": "Hagrid's Magical Creatures Motorbike Adventure Single Rider", "type": "coaster", "description": "Single rider line for Hagrid's Magical Creatures Motorbike Adventure.", "minHeight": 48, "latitude": 28.47308, "longitude": -81.472862, "tpwUuid": "578bbd12-1975-4ec3-9879-ea641c780342"},
    {"id": 5992, "parkId": 64, "name": "Harry Potter and the Forbidden Journey", "type": "darkride", "description": "Soar above Hogwarts on the magical bench through Quidditch and Dementor scenes.", "minHeight": 48, "latitude": 28.472265, "longitude": -81.4735195, "tpwUuid": "6af80308-647d-4d8b-bcf6-37517a93bdbc"},
    {"id": 13113, "parkId": 64, "name": "Harry Potter and the Forbidden Journey Single Rider", "type": "darkride", "description": "Single rider line for Harry Potter and the Forbidden Journey.", "minHeight": 48, "latitude": 28.472265, "longitude": -81.4735195, "tpwUuid": "6af80308-647d-4d8b-bcf6-37517a93bdbc"},
    {"id": 6015, "parkId": 64, "name": "Hogwarts Express - Hogsmeade Station", "type": "train", "description": "Ride from Hogsmeade Station to King's Cross Station (park-to-park ticket required).", "minHeight": null, "latitude": 28.47348, "longitude": -81.472594, "tpwUuid": "144450b9-4574-46be-abdf-4b1ca8974d9d"},
    {"id": 13098, "parkId": 64, "name": "Ollivanders Experience in Hogsmeade", "type": "experience", "description": "Interactive wand-selection ceremony.", "minHeight": null, "latitude": 28.472809, "longitude": -81.473077, "tpwUuid": "d7310719-f158-4d92-a476-13202c7162cd"},
    {"id": 5986, "parkId": 64, "name": "Caro-Seuss-el", "type": "carousel", "description": "Spin on a carousel of whimsical Dr. Seuss creatures.", "minHeight": null, "latitude": 28.473017, "longitude": -81.469916, "tpwUuid": "3cb52134-e9d6-4212-83c8-3ce1321dcb05"},
    {"id": 5987, "parkId": 64, "name": "The Cat in The Hat", "type": "darkride", "description": "A whimsical dark ride through the classic Dr. Seuss story.", "minHeight": 36, "latitude": 28.472969, "longitude": -81.46928, "tpwUuid": "2365495a-790b-4a41-831e-65592c8a4359"},
    {"id": 5997, "parkId": 64, "name": "One Fish, Two Fish, Red Fish, Blue Fish", "type": "spinner", "description": "Spin in a colorful fish-shaped vehicle while singing along.", "minHeight": null, "latitude": 28.473086, "longitude": -81.469486, "tpwUuid": "b1e94e05-b360-4e3f-be8a-2a3744a97f97"},
    {"id": 6001, "parkId": 64, "name": "The High in the Sky Seuss Trolley Train Ride!", "type": "train", "description": "A scenic elevated trolley above Seuss Landing.", "minHeight": 36, "latitude": 28.473011, "longitude": -81.470178, "tpwUuid": "b73e3256-9ee0-439e-9a3b-ffed287e10bb"},
    {"id": 6011, "parkId": 64, "name": "If I Ran The Zoo", "type": "experience", "description": "Interactive playground area with three sections of Seussian zoo creatures.", "minHeight": null, "latitude": 28.472643, "longitude": -81.4696767, "tpwUuid": "391dea99-303d-42a1-aa86-a846d1c1fa1f"},
    {"id": 13605, "parkId": 65, "name": "Trolls Trollercoaster", "type": "coaster", "description": "Family-friendly coaster themed to the Trolls franchise (replaced Woody Woodpecker's Nuthouse Coaster).", "minHeight": 36, "latitude": 28.47842, "longitude": -81.46611, "tpwUuid": "37989fb7-5576-4247-bd6e-e981bc70cca2"},
    {"id": 5990, "parkId": 65, "name": "E.T. Adventure", "type": "darkride", "description": "Fly on a bicycle to help E.T. save his home planet - original USF opening-day ride.", "minHeight": 34, "latitude": 28.478075, "longitude": -81.466783, "tpwUuid": "1e16afdd-15e3-4e4a-b3af-8aeebd7534f8"},
    {"id": 5984, "parkId": 65, "name": "Despicable Me Minion Mayhem", "type": "simulator", "description": "Join the Minions on a wild 3D simulator ride.", "minHeight": 40, "latitude": 28.4753199, "longitude": -81.4678895, "tpwUuid": "7288f24a-396e-4eeb-bb3b-4a90e65269f2"},
    {"id": 12186, "parkId": 65, "name": "Illumination Theater", "type": "show", "description": "Live show featuring Illumination characters in Minion Land.", "minHeight": null, "latitude": 28.475880741324, "longitude": -81.4683399259803, "tpwUuid": "a8382eac-3a99-48fe-bb52-b90b72d074dc"},
    {"id": 12107, "parkId": 65, "name": "Illumination's Villain-Con Minion Blast", "type": "shooter", "description": "An interactive shooter ride competing for Vicious 6 status.", "minHeight": 40, "latitude": 28.475526, "longitude": -81.467882, "tpwUuid": "25d47d04-a917-405a-9904-9be2b499b2dd"},
    {"id": 6018, "parkId": 65, "name": "Race Through New York Starring Jimmy Fallon", "type": "simulator", "description": "A 3D motion-simulator race through NYC with Jimmy Fallon.", "minHeight": 40, "latitude": 28.475881, "longitude": -81.469363, "tpwUuid": "625a3cc3-7d7e-468b-96fe-1ec00df7b739"},
    {"id": 6000, "parkId": 65, "name": "Revenge of the Mummy", "type": "coaster", "description": "An indoor coaster with intense special effects and a backwards section.", "minHeight": 48, "latitude": 28.4766, "longitude": -81.46954, "tpwUuid": "ec25d9a7-b4d4-4ebf-a6c4-c18389351764"},
    {"id": 13110, "parkId": 65, "name": "Revenge of the Mummy Single Rider", "type": "coaster", "description": "Single rider line for Revenge of the Mummy.", "minHeight": 48, "latitude": 28.4766, "longitude": -81.46954, "tpwUuid": "ec25d9a7-b4d4-4ebf-a6c4-c18389351764"},
    {"id": 5993, "parkId": 65, "name": "Hollywood Rip Ride Rockit", "type": "coaster", "description": "A high-speed musical coaster with a 167-foot vertical lift.", "minHeight": 51, "latitude": 28.47517, "longitude": -81.46856, "tpwUuid": "2c72d1d0-7106-439d-9672-5bf95795ccea"},
    {"id": 6006, "parkId": 65, "name": "TRANSFORMERS: The Ride-3D", "type": "darkride", "description": "An immersive 3D dark ride battling alongside the Autobots.", "minHeight": 40, "latitude": 28.47669, "longitude": -81.46856, "tpwUuid": "750939c5-a69e-408a-8d55-66c272fa265e"},
    {"id": 6038, "parkId": 65, "name": "Fast & Furious - Supercharged", "type": "darkride", "description": "A high-octane dark ride with the Fast & Furious crew (announced to close in 2027).", "minHeight": 40, "latitude": 28.477888, "longitude": -81.469458, "tpwUuid": "6a3ffac7-bef4-4a22-8ba6-f2963aac7f70"},
    {"id": 14866, "parkId": 65, "name": "Fast & Furious - Supercharged Single Rider", "type": "darkride", "description": "Single rider line for Fast & Furious - Supercharged.", "minHeight": 40, "latitude": 28.477888, "longitude": -81.469458, "tpwUuid": "6a3ffac7-bef4-4a22-8ba6-f2963aac7f70"},
    {"id": 6014, "parkId": 65, "name": "Harry Potter and the Escape from Gringotts", "type": "coaster", "description": "A 3D dark ride and roller coaster hybrid through the wizarding bank.", "minHeight": 42, "latitude": 28.479719, "longitude": -81.469922, "tpwUuid": "70ac72a3-9675-4c41-a1b1-e4801072927a"},
    {"id": 15416, "parkId": 65, "name": "Harry Potter and the Escape from Gringotts Single Rider", "type": "coaster", "description": "Single rider line for Harry Potter and the Escape from Gringotts.", "minHeight": 42, "latitude": 28.479719, "longitude": -81.469922, "tpwUuid": "70ac72a3-9675-4c41-a1b1-e4801072927a"},
    {"id": 6016, "parkId": 65, "name": "Hogwarts Express - King's Cross Station", "type": "train", "description": "Travel from London to Hogsmeade Station (park-to-park ticket required).", "minHeight": null, "latitude": 28.479079, "longitude": -81.46944, "tpwUuid": "f0750e5e-7629-4c53-99d2-e0924a8afeed"},
    {"id": 13849, "parkId": 65, "name": "Hogwarts Express - First Train", "type": "train", "description": "Earlier-departure Hogwarts Express experience from King's Cross.", "minHeight": null, "latitude": 28.479079, "longitude": -81.46944, "tpwUuid": "f44a531c-09cf-40c4-b2d4-236e8a9285dc"},
    {"id": 13100, "parkId": 65, "name": "Ollivanders Experience in Diagon Alley", "type": "experience", "description": "Interactive wand-selection ceremony in Diagon Alley.", "minHeight": null, "latitude": 28.47964, "longitude": -81.46973, "tpwUuid": "e99b72a6-37d0-46df-ab11-e9ff6603f259"},
    {"id": 5995, "parkId": 65, "name": "Kang & Kodos' Twirl 'n' Hurl", "type": "spinner", "description": "A spinning ride hosted by the aliens from The Simpsons.", "minHeight": null, "latitude": 28.479352, "longitude": -81.467877, "tpwUuid": "96e71193-49f0-40b2-9bba-644e530d8115"},
    {"id": 5996, "parkId": 65, "name": "MEN IN BLACK Alien Attack!", "type": "shooter", "description": "An interactive shooter ride zapping aliens with cadet training.", "minHeight": 42, "latitude": 28.480441, "longitude": -81.468043, "tpwUuid": "91cae293-64f8-48b6-88ec-02dcfcdd1f91"},
    {"id": 14517, "parkId": 65, "name": "MEN IN BLACK Alien Attack! Single Rider", "type": "shooter", "description": "Single rider line for MEN IN BLACK Alien Attack.", "minHeight": 42, "latitude": 28.480441, "longitude": -81.468043, "tpwUuid": "91cae293-64f8-48b6-88ec-02dcfcdd1f91"},
    {"id": 6005, "parkId": 65, "name": "The Simpsons Ride", "type": "simulator", "description": "A motion simulator ride through Krustyland with The Simpsons.", "minHeight": 40, "latitude": 28.479604, "longitude": -81.467788, "tpwUuid": "7e70bc9e-7dce-4dd2-8823-57b8d6ec7570"},
    {"id": 14688, "parkId": 334, "name": "Constellation Carousel", "type": "carousel", "description": "A grand carousel at the heart of Celestial Park.", "minHeight": null, "latitude": 28.44033, "longitude": -81.44805, "tpwUuid": "07143999-bacd-475f-a00b-8cc476204aff"},
    {"id": 14690, "parkId": 334, "name": "Stardust Racers", "type": "coaster", "description": "A high-speed dual-launch racing coaster.", "minHeight": 48, "latitude": 28.44151, "longitude": -81.44753, "tpwUuid": "447033ce-ee1f-4cca-bb12-47d22583ac12"},
    {"id": 14740, "parkId": 334, "name": "Stardust Racers Single Rider", "type": "coaster", "description": "Single rider line for Stardust Racers.", "minHeight": 48, "latitude": 28.44151, "longitude": -81.44753, "tpwUuid": "447033ce-ee1f-4cca-bb12-47d22583ac12"},
    {"id": 14692, "parkId": 334, "name": "Curse of the Werewolf", "type": "coaster", "description": "A spinning launch coaster through a haunted European village.", "minHeight": 40, "latitude": 28.43995, "longitude": -81.45002, "tpwUuid": "eaca831d-bcbb-4a1e-9bf0-6ea97ccc88e0"},
    {"id": 14698, "parkId": 334, "name": "Curse of the Werewolf Single Rider", "type": "coaster", "description": "Single rider line for Curse of the Werewolf.", "minHeight": 40, "latitude": 28.43995, "longitude": -81.45002, "tpwUuid": "eaca831d-bcbb-4a1e-9bf0-6ea97ccc88e0"},
    {"id": 14694, "parkId": 334, "name": "Monsters Unchained: The Frankenstein Experiment", "type": "darkride", "description": "A trackless multi-stage dark ride through Frankenstein's lab and the Universal Monsters.", "minHeight": 48, "latitude": 28.44035, "longitude": -81.45029, "tpwUuid": "1fda5e1f-8712-4165-a81d-ad74eef3e8ee"},
    {"id": 14699, "parkId": 334, "name": "Monsters Unchained: The Frankenstein Experiment Single Rider", "type": "darkride", "description": "Single rider line for Monsters Unchained.", "minHeight": 48, "latitude": 28.44035, "longitude": -81.45029, "tpwUuid": "1fda5e1f-8712-4165-a81d-ad74eef3e8ee"},
    {"id": 14685, "parkId": 334, "name": "Meet Toothless and Friends", "type": "meet", "description": "Meet Toothless, Light Fury, and other dragons from How to Train Your Dragon.", "minHeight": null, "latitude": 28.4408, "longitude": -81.44624, "tpwUuid": "9d47d7fe-ff0d-4a52-bf9d-1e07436aa22c"},
    {"id": 14691, "parkId": 334, "name": "Fyre Drill", "type": "experience", "description": "Interactive water cannon battle between two boats.", "minHeight": null, "latitude": 28.44061, "longitude": -81.44545, "tpwUuid": "281bc9e6-b208-4a70-85d2-0fb749c7658b"},
    {"id": 14693, "parkId": 334, "name": "Dragon Racer's Rally", "type": "spinner", "description": "A spinning aerial ride themed to the Dragon Racing championship.", "minHeight": null, "latitude": 28.44122, "longitude": -81.44549, "tpwUuid": "76caa8d0-f54b-4601-9d57-a7f1ddc02af4"},
    {"id": 14695, "parkId": 334, "name": "Hiccup Wing Glider", "type": "coaster", "description": "A family-friendly dragon-themed coaster across the Isle of Berk.", "minHeight": 42, "latitude": 28.44113, "longitude": -81.44548, "tpwUuid": "c6b1b8cf-55ef-416c-b00d-e469993617b0"},
    {"id": 14682, "parkId": 334, "name": "Bowser Jr. Challenge", "type": "shooter", "description": "Interactive shooter attraction in Super Nintendo World.", "minHeight": null, "latitude": 28.439046, "longitude": -81.447956, "tpwUuid": "0c6a9af8-c006-4849-8475-1a6925e8f7d4"},
    {"id": 14683, "parkId": 334, "name": "Mario Kart: Bowser's Challenge", "type": "darkride", "description": "AR-based dark ride through Mario Kart courses with steering and shells.", "minHeight": 40, "latitude": 28.43875, "longitude": -81.44783, "tpwUuid": "43df71bf-aa7c-46c0-925c-46f69d8bf23f"},
    {"id": 14684, "parkId": 334, "name": "Mario Kart: Bowser's Challenge Single Rider", "type": "darkride", "description": "Single rider line for Mario Kart: Bowser's Challenge.", "minHeight": 40, "latitude": 28.43875, "longitude": -81.44783, "tpwUuid": "43df71bf-aa7c-46c0-925c-46f69d8bf23f"},
    {"id": 14689, "parkId": 334, "name": "Yoshi's Adventure", "type": "darkride", "description": "A gentle family ride aboard Yoshi vehicles searching for Captain Toad.", "minHeight": 34, "latitude": 28.43904, "longitude": -81.44817, "tpwUuid": "00feb57b-4fcc-48bc-9490-c9af71f30c1c"},
    {"id": 14686, "parkId": 334, "name": "Mine-Cart Madness", "type": "coaster", "description": "A family coaster through Donkey Kong Country with simulated jumping mine carts.", "minHeight": 36, "latitude": 28.43825, "longitude": -81.44875, "tpwUuid": "dd8c015d-511f-47d4-b98b-18ce15735588"},
    {"id": 14697, "parkId": 334, "name": "Mine-Cart Madness Single Rider", "type": "coaster", "description": "Single rider line for Mine-Cart Madness.", "minHeight": 36, "latitude": 28.43825, "longitude": -81.44875, "tpwUuid": "dd8c015d-511f-47d4-b98b-18ce15735588"},
    {"id": 14687, "parkId": 334, "name": "Harry Potter and the Battle at the Ministry", "type": "darkride", "description": "A multi-vehicle dark ride through the Ministry of Magic during the Death Eater era.", "minHeight": 48, "latitude": 28.44284, "longitude": -81.4481, "tpwUuid": "dbc4f0d8-fdef-4dfc-a1c2-33917f742f40"},
    {"id": 14696, "parkId": 334, "name": "Harry Potter and the Battle at the Ministry Single Rider", "type": "darkride", "description": "Single rider line for Harry Potter and the Battle at the Ministry.", "minHeight": 48, "latitude": 28.44284, "longitude": -81.4481, "tpwUuid": "dbc4f0d8-fdef-4dfc-a1c2-33917f742f40"}
    ]
    """
}
