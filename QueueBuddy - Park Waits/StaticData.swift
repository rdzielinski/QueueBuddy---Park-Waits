import Foundation
import MapKit

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
    static let parkCoordinates: [Int: (lat: Double, lon: Double)] = [
         5: (28.3747, -81.5494),
         6: (28.4177, -81.5812),
         7: (28.3575, -81.5581),
         8: (28.3553, -81.5912),
         64: (28.4717, -81.4731),
         65: (28.4743, -81.4678),
         334: (28.4603, -81.4803)
     ]
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
    }

    static func getAttractionDetails() -> [Int: (name: String, parkId: Int, type: String?, description: String?, minHeight: Int?, lat: Double?, lon: Double?)] {
        guard let data = attractionsJSON.data(using: .utf8) else {
            fatalError("Could not convert static attractions JSON string to Data.")
        }
        do {
            let details = try JSONDecoder().decode([AttractionDetail].self, from: data)
            var detailsMap = [Int: (name: String, parkId: Int, type: String?, description: String?, minHeight: Int?, lat: Double?, lon: Double?)]()
            for detail in details {
                detailsMap[detail.id] = (detail.name, detail.parkId, detail.type, detail.description, detail.minHeight, detail.latitude, detail.longitude)
            }
            return detailsMap
        } catch {
            fatalError("Error decoding static attraction details: \(error)")
        }
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
    
    static let attractionToLandMapping: [Int: String] = [
        // ───────────────────────────────────────────────────────────────
        // MAGIC KINGDOM (parkId 6)
        // ───────────────────────────────────────────────────────────────

        // Main Street, U.S.A.
        146:   "Main Street, U.S.A.",   // Meet Mickey at Town Square Theater
        1188:  "Main Street, U.S.A.",   // Main Street Vehicles
        1189:  "Main Street, U.S.A.",   // WDW Railroad - Main Street

        // Adventureland
        134:   "Adventureland",         // Jungle Cruise
        137:   "Adventureland",         // Pirates of the Caribbean
        141:   "Adventureland",         // The Magic Carpets of Aladdin
        334:   "Adventureland",         // Walt Disney's Enchanted Tiki Room
        355:   "Adventureland",         // Swiss Family Treehouse
        1184:  "Adventureland",         // A Pirate's Adventure

        // Frontierland
        130:   "Frontierland",          // Big Thunder Mountain Railroad
        465:   "Frontierland",          // Tom Sawyer Island
        1179:  "Frontierland",          // WDW Railroad - Frontierland
        1214:  "Frontierland",          // Country Bear Musical Jamboree
        13630: "Frontierland",          // Tiana's Bayou Adventure

        // Liberty Square
        140:   "Liberty Square",        // Haunted Mansion
        356:   "Liberty Square",        // The Hall of Presidents
        1187:  "Liberty Square",        // Liberty Square Riverboat

        // Fantasyland
        126:   "Fantasyland",           // The Barnstormer
        127:   "Fantasyland",           // Under the Sea - Journey of The Little Mermaid
        128:   "Fantasyland",           // Enchanted Tales with Belle
        129:   "Fantasyland",           // Seven Dwarfs Mine Train
        132:   "Fantasyland",           // Dumbo the Flying Elephant
        133:   "Fantasyland",           // "it's a small world"
        135:   "Fantasyland",           // Mad Tea Party
        136:   "Fantasyland",           // Peter Pan's Flight
        142:   "Fantasyland",           // The Many Adventures of Winnie the Pooh
        144:   "Fantasyland",           // Meet Daring Disney Pals at Pete's Silly Sideshow
        145:   "Fantasyland",           // Meet Dashing Disney Pals at Pete's Silly Sideshow
        147:   "Fantasyland",           // Meet Ariel at Her Grotto
        161:   "Fantasyland",           // Prince Charming Regal Carrousel
        171:   "Fantasyland",           // Mickey's PhilharMagic
        1181:  "Fantasyland",           // WDW Railroad - Fantasyland
        6699:  "Fantasyland",           // Meet Princess Tiana at Princess Fairytale Hall
        6700:  "Fantasyland",           // Meet Cinderella at Princess Fairytale Hall
        13763: "Fantasyland",           // Cinderella Castle
        13764: "Fantasyland",           // Casey Jr. Splash 'N' Soak Station

        // Tomorrowland
        125:   "Tomorrowland",          // Monsters Inc. Laugh Floor
        131:   "Tomorrowland",          // Buzz Lightyear's Space Ranger Spin
        138:   "Tomorrowland",          // Space Mountain
        143:   "Tomorrowland",          // Tomorrowland Speedway
        248:   "Tomorrowland",          // Astro Orbiter
        457:   "Tomorrowland",          // Walt Disney's Carousel of Progress
        1190:  "Tomorrowland",          // Tomorrowland Transit Authority PeopleMover
        11527: "Tomorrowland",          // TRON Lightcycle / Run

        // ───────────────────────────────────────────────────────────────
        // EPCOT (parkId 5)
        // ───────────────────────────────────────────────────────────────

        // World Celebration (central hub — Spaceship Earth, CommuniCore)
        159:   "World Celebration",     // Spaceship Earth
        13627: "World Celebration",     // Meet Beloved Disney Pals at Mickey & Friends
        13775: "World Celebration",     // Project Tomorrow (SE post-show)

        // World Discovery (east — future/thrill)
        158:   "World Discovery",       // Mission: SPACE
        160:   "World Discovery",       // Test Track
        10916: "World Discovery",       // Guardians of the Galaxy: Cosmic Rewind
        13774: "World Discovery",       // Advanced Training Lab (Mission: SPACE)

        // World Nature (west — nature/Imagination/Land/Seas)
        151:   "World Nature",          // Soarin' Around the World
        152:   "World Nature",          // Turtle Talk With Crush
        153:   "World Nature",          // The Seas with Nemo & Friends
        155:   "World Nature",          // Journey Into Imagination With Figment
        156:   "World Nature",          // Living with the Land
        2495:  "World Nature",          // Disney and Pixar Short Film Festival (Imagination)
        7323:  "World Nature",          // Awesome Planet (The Land)
        12387: "World Nature",          // Journey of Water, Inspired by Moana
        13770: "World Nature",          // Bruce's Shark World (Seas)
        13777: "World Nature",          // ImageWorks - The "What If" Labs (Imagination)
        13782: "World Nature",          // SeaBase Aquarium (Seas)

        // World Showcase (pavilions)
        466:   "World Showcase",        // Gran Fiesta Tour (Mexico)
        829:   "World Showcase",        // Canada Far and Wide (Canada)
        2679:  "World Showcase",        // Frozen Ever After (Norway)
        6701:  "World Showcase",        // Meet Anna and Elsa at Royal Sommerhus (Norway)
        10914: "World Showcase",        // Remy's Ratatouille Adventure (France)
        10915: "World Showcase",        // Remy's Ratatouille Single Rider (France)
        13767: "World Showcase",        // House of the Whispering Willows (China)
        13772: "World Showcase",        // Gallery of Arts and History
        13773: "World Showcase",        // American Heritage Gallery
        13776: "World Showcase",        // Stave Church Gallery (Norway)
        13778: "World Showcase",        // Kidcot Fun Stops
        13779: "World Showcase",        // Palais du Cinéma (France)
        13780: "World Showcase",        // Mexico Folk Art Gallery
        13781: "World Showcase",        // Bijutsu-kan Gallery (Japan)

        // ───────────────────────────────────────────────────────────────
        // DISNEY'S HOLLYWOOD STUDIOS (parkId 7)
        // ───────────────────────────────────────────────────────────────

        // Hollywood Boulevard
        6361:  "Hollywood Boulevard",   // Mickey & Minnie's Runaway Railway

        // Sunset Boulevard
        119:   "Sunset Boulevard",      // Rock 'n' Roller Coaster
        123:   "Sunset Boulevard",      // Tower of Terror
        1176:  "Sunset Boulevard",      // Beauty and the Beast – Live on Stage
        10901: "Sunset Boulevard",      // Rock 'n' Roller Coaster Single Rider

        // Echo Lake
        120:   "Echo Lake",             // Star Tours
        1174:  "Echo Lake",             // For the First Time in Forever (Hyperion)
        6702:  "Echo Lake",             // Indiana Jones Epic Stunt Spectacular
        6703:  "Echo Lake",             // Meet Olaf at Celebrity Spotlight
        7333:  "Echo Lake",             // Vacation Fun

        // Animation Courtyard
        2478:  "Animation Courtyard",   // Star Wars Launch Bay
        2574:  "Animation Courtyard",   // Launch Bay: Darth Vader
        2577:  "Animation Courtyard",   // Launch Bay: Chewbacca
        2663:  "Animation Courtyard",   // Star Wars Launch Bay Theater
        5145:  "Animation Courtyard",   // Walt Disney Presents
        6704:  "Animation Courtyard",   // Meet Disney Stars at Red Carpet Dreams
        6705:  "Animation Courtyard",   // Launch Bay: BB-8
        12425: "Animation Courtyard",   // Meet Edna Mode
        12430: "Animation Courtyard",   // Meet Ariel at Walt Disney Presents

        // Toy Story Land
        117:   "Toy Story Land",        // Toy Story Mania!
        5476:  "Toy Story Land",        // Slinky Dog Dash
        5477:  "Toy Story Land",        // Alien Swirling Saucers

        // Star Wars: Galaxy's Edge
        6368:  "Star Wars: Galaxy's Edge",   // Millennium Falcon: Smugglers Run
        6369:  "Star Wars: Galaxy's Edge",   // Rise of the Resistance
        10902: "Star Wars: Galaxy's Edge",   // Millennium Falcon Single Rider
        14531: "Star Wars: Galaxy's Edge",   // Rise of the Resistance Single Rider

        // ───────────────────────────────────────────────────────────────
        // ANIMAL KINGDOM (parkId 8)
        // ───────────────────────────────────────────────────────────────

        // The Oasis / park-wide
        13808: "The Oasis",             // Wilderness Explorers
        13812: "The Oasis",             // The Oasis Exhibits

        // Discovery Island
        116:   "Discovery Island",      // Meet Favorite Disney Pals at Adventurers Outpost
        12451: "Discovery Island",      // Meet Moana at Character Landing
        13751: "Discovery Island",      // Tree of Life
        13811: "Discovery Island",      // Discovery Island Trails

        // Africa
        113:   "Africa",                // Kilimanjaro Safaris
        651:   "Africa",                // Gorilla Falls Exploration Trail
        655:   "Africa",                // Wildlife Express Train
        657:   "Africa",                // Festival of the Lion King

        // Rafiki's Planet Watch
        6680:  "Rafiki's Planet Watch", // The Animation Experience
        13806: "Rafiki's Planet Watch", // Conservation Station
        13807: "Rafiki's Planet Watch", // Affection Section

        // Asia
        110:   "Asia",                  // Expedition Everest
        112:   "Asia",                  // Kali River Rapids
        10921: "Asia",                  // Feathered Friends in Flight (Caravan Stage)
        14533: "Asia",                  // Expedition Everest Single Rider

        // DinoLand U.S.A.
        111:   "DinoLand U.S.A.",       // DINOSAUR
        652:   "DinoLand U.S.A.",       // The Boneyard
        10920: "DinoLand U.S.A.",       // Finding Nemo: The Big Blue
        13809: "DinoLand U.S.A.",       // Dino-Sue

        // Pandora - The World of Avatar
        4438:  "Pandora - The World of Avatar",   // Na'vi River Journey
        4439:  "Pandora - The World of Avatar",   // Avatar Flight of Passage

        // ───────────────────────────────────────────────────────────────
        // UNIVERSAL STUDIOS FLORIDA (parkId 65)
        // ───────────────────────────────────────────────────────────────

        // Production Central
        6018:  "Production Central",    // Despicable Me Minion Mayhem
        12107: "Production Central",    // Transformers: The Ride-3D
        13605: "Production Central",    // Hollywood Rip Ride Rockit

        // New York
        6021:  "New York",              // Race Through New York Starring Jimmy Fallon
        6022:  "New York",              // Revenge of the Mummy

        // San Francisco
        6038:  "San Francisco",         // Fast & Furious – Supercharged

        // The Wizarding World of Harry Potter — Diagon Alley (includes London)
        6000:  "The Wizarding World of Harry Potter - Diagon Alley", // Escape from Gringotts
        6016:  "The Wizarding World of Harry Potter - Diagon Alley", // Hogwarts Express - King's Cross

        // World Expo
        5984:  "World Expo",            // MEN IN BLACK Alien Attack

        // Springfield, U.S.A.
        6039:  "Springfield, U.S.A.",   // The Simpsons Ride
        13110: "Springfield, U.S.A.",   // Kang & Kodos' Twirl 'n' Hurl

        // DreamWorks Land (formerly Woody Woodpecker's KidZone, rethemed 2024)
        13111: "DreamWorks Land",       // E.T. Adventure

        // Hollywood
        6025:  "Hollywood",             // The Bourne Stuntacular
        6026:  "Hollywood",             // Horror Make-Up Show

        // ───────────────────────────────────────────────────────────────
        // UNIVERSAL'S ISLANDS OF ADVENTURE (parkId 64)
        // ───────────────────────────────────────────────────────────────

        // Marvel Super Hero Island
        5985:  "Marvel Super Hero Island",  // Amazing Adventures of Spider-Man
        5988:  "Marvel Super Hero Island",  // Doctor Doom's Fearfall
        6003:  "Marvel Super Hero Island",  // Storm Force Accelatron
        6004:  "Marvel Super Hero Island",  // Incredible Hulk Coaster

        // Toon Lagoon
        5989:  "Toon Lagoon",               // Dudley Do-Right's Ripsaw Falls
        5998:  "Toon Lagoon",               // Popeye & Bluto's Bilge-Rat Barges
        6013:  "Toon Lagoon",               // Me Ship, The Olive

        // Jurassic Park
        5994:  "Jurassic Park",             // Jurassic Park River Adventure
        5999:  "Jurassic Park",             // Pteranodon Flyers
        6008:  "Jurassic Park",             // Camp Jurassic
        6012:  "Jurassic Park",             // Jurassic Park Discovery Center
        6017:  "Jurassic Park",             // Skull Island: Reign of Kong (sited on the Jurassic border)
        8721:  "Jurassic Park",             // Jurassic World VelociCoaster
        13109: "Jurassic Park",             // VelociCoaster Single Rider

        // The Wizarding World of Harry Potter — Hogsmeade
        5991:  "The Wizarding World of Harry Potter - Hogsmeade",   // Flight of the Hippogriff
        5992:  "The Wizarding World of Harry Potter - Hogsmeade",   // Forbidden Journey
        6015:  "The Wizarding World of Harry Potter - Hogsmeade",   // Hogwarts Express - Hogsmeade Station
        6682:  "The Wizarding World of Harry Potter - Hogsmeade",   // Hagrid's Motorbike Adventure
        13098: "The Wizarding World of Harry Potter - Hogsmeade",   // Ollivanders in Hogsmeade

        // Seuss Landing
        5986:  "Seuss Landing",             // Caro-Seuss-el
        5987:  "Seuss Landing",             // The Cat in The Hat
        5997:  "Seuss Landing",             // One Fish, Two Fish
        6001:  "Seuss Landing",             // High in the Sky Seuss Trolley Train
        6011:  "Seuss Landing",             // If I Ran The Zoo

        // ───────────────────────────────────────────────────────────────
        // UNIVERSAL EPIC UNIVERSE (parkId 334)
        // ───────────────────────────────────────────────────────────────

        // Celestial Park
        14688: "Celestial Park",            // Constellation Carousel
        14690: "Celestial Park",            // Stardust Racers
        14740: "Celestial Park",            // Stardust Racers Single Rider

        // Dark Universe
        14692: "Dark Universe",             // Curse of the Werewolf
        14694: "Dark Universe",             // Monsters Unchained
        14698: "Dark Universe",             // Curse of the Werewolf Single Rider

        // How to Train Your Dragon - Isle of Berk
        14685: "How to Train Your Dragon - Isle of Berk",   // Meet Toothless
        14691: "How to Train Your Dragon - Isle of Berk",   // Fyre Drill
        14693: "How to Train Your Dragon - Isle of Berk",   // Dragon Racer's Rally
        14695: "How to Train Your Dragon - Isle of Berk",   // Hiccup Wing Glider

        // Super Nintendo World
        14682: "Super Nintendo World",                      // Bowser Jr. Challenge
        14683: "Super Nintendo World",                      // Mario Kart: Bowser's Challenge
        14684: "Super Nintendo World",                      // Mario Kart Single Rider
        14689: "Super Nintendo World",                      // Yoshi's Adventure

        // Donkey Kong Country (sub-land of Super Nintendo World)
        14686: "Super Nintendo World - Donkey Kong Country", // Mine-Cart Madness
        14697: "Super Nintendo World - Donkey Kong Country", // Mine-Cart Madness Single Rider

        // The Wizarding World of Harry Potter - Ministry of Magic
        14687: "The Wizarding World of Harry Potter - Ministry of Magic", // Battle at the Ministry
        14696: "The Wizarding World of Harry Potter - Ministry of Magic", // Battle at the Ministry SR
    ]

    /// Returns true if a land name looks seasonal (Halloween Horror Nights
    /// houses, holiday overlays, etc.). Lands like "Other Attractions" are
    /// also treated as seasonal so that scare-zone content pulled from the
    /// live API — which has no static land mapping — starts collapsed.
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

    /// **THIS IS THE CORRECTED FUNCTION**
    /// It takes the attraction type string (e.g., "meet") and returns a
    /// valid SF Symbol name (e.g., "person.2.fill").
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
                return "person.2.fill" // This is the fix for your "meet" error
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
    
    private static let attractionsJSON = """
    [
      {"id": 1184, "parkId": 6, "name": "A Pirate's Adventure ~ Treasures of the Seven Seas", "type": "experience", "description": "Interactive treasure hunt in Adventureland.", "minHeight": null, "latitude": 28.418, "longitude": -81.586},
      {"id": 134, "parkId": 6, "name": "Jungle Cruise", "type": "boat", "description": "Embark on a guided tour down the rivers of the world.", "minHeight": null, "latitude": 28.4162, "longitude": -81.5862},
      {"id": 137, "parkId": 6, "name": "Pirates of the Caribbean", "type": "boat", "description": "Set sail on a swashbuckling voyage through pirate-infested waters.", "minHeight": null, "latitude": 28.4168, "longitude": -81.5857},
      {"id": 355, "parkId": 6, "name": "Swiss Family Treehouse", "type": "experience", "description": "Climb and explore the iconic treehouse.", "minHeight": null, "latitude": 28.4200, "longitude": -81.5812},
      {"id": 141, "parkId": 6, "name": "The Magic Carpets of Aladdin", "type": "spinner", "description": "Soar high above Adventureland on a gently flying magic carpet.", "minHeight": null, "latitude": 28.4140, "longitude": -81.5859},
      {"id": 334, "parkId": 6, "name": "Walt Disney's Enchanted Tiki Room", "type": "show", "description": "Tropical birds and colorful flowers come to life in this classic musical show.", "minHeight": null, "latitude": 28.4155, "longitude": -81.5855},
      {"id": 133, "parkId": 6, "name": "\\"it's a small world\\"", "type": "boat", "description": "Take a gentle boat tour and sing along with dolls from all over the globe.", "minHeight": null, "latitude": 28.4208, "longitude": -81.5807},
      {"id": 13764, "parkId": 6, "name": "Casey Jr. Splash 'N' Soak Station", "type": "experience", "description": "Water play area for kids.", "minHeight": null, "latitude": 28.4212, "longitude": -81.5815},
      {"id": 13763, "parkId": 6, "name": "Cinderella Castle", "type": "experience", "description": "Iconic castle and photo spot.", "minHeight": null, "latitude": 28.4195, "longitude": -81.5820},
      {"id": 132, "parkId": 6, "name": "Dumbo the Flying Elephant", "type": "spinner", "description": "Fly high above Fantasyland on a classic attraction.", "minHeight": null, "latitude": 28.4200, "longitude": -81.5800},
      {"id": 128, "parkId": 6, "name": "Enchanted Tales with Belle", "type": "show", "description": "Become part of a heartwarming story with Belle and Lumiere.", "minHeight": null, "latitude": 28.4210, "longitude": -81.5810},
      {"id": 135, "parkId": 6, "name": "Mad Tea Party", "type": "spinner", "description": "Spin ‘round and ‘round in a giant teacup.", "minHeight": null, "latitude": 28.4195, "longitude": -81.5805},
      {"id": 147, "parkId": 6, "name": "Meet Ariel at Her Grotto", "type": "meet", "description": "Meet Ariel in her undersea grotto.", "minHeight": null, "latitude": 28.4202, "longitude": -81.5811},
      {"id": 6700, "parkId": 6, "name": "Meet Cinderella and a Visiting Princess at Princess Fairytale Hall", "type": "meet", "description": "Meet Cinderella and a visiting princess.", "minHeight": null, "latitude": 28.4218, "longitude": -81.5825},
      {"id": 144, "parkId": 6, "name": "Meet Daring Disney Pals as Circus Stars at Pete's Silly Sideshow", "type": "meet", "description": "Meet Disney pals in circus costumes.", "minHeight": null, "latitude": 28.421, "longitude": -81.581},
      {"id": 145, "parkId": 6, "name": "Meet Dashing Disney Pals as Circus Stars at Pete's Silly Sideshow", "type": "meet", "description": "Meet Disney pals in circus costumes.", "minHeight": null, "latitude": 28.4218, "longitude": -81.5822},
      {"id": 6699, "parkId": 6, "name": "Meet Princess Tiana and a Visiting Princess at Princess Fairytale Hall", "type": "meet", "description": "Meet Princess Tiana and a visiting princess.", "minHeight": null, "latitude": 28.4218, "longitude": -81.5820},
      {"id": 171, "parkId": 6, "name": "Mickey's PhilharMagic", "type": "show", "description": "A 3D movie extravaganza starring many favorite Disney characters.", "minHeight": null, "latitude": 28.4208, "longitude": -81.5800},
      {"id": 136, "parkId": 6, "name": "Peter Pan's Flight", "type": "darkride", "description": "Soar through the skies of London to Never Land in a pirate galleon.", "minHeight": null, "latitude": 28.4203, "longitude": -81.5821},
      {"id": 161, "parkId": 6, "name": "Prince Charming Regal Carrousel", "type": "carousel", "description": "Enjoy a classic carousel ride in the heart of Fantasyland.", "minHeight": null, "latitude": 28.4195, "longitude": -81.5820},
      {"id": 129, "parkId": 6, "name": "Seven Dwarfs Mine Train", "type": "coaster", "description": "Embark on a daring quest to retrieve a diamond from the Seven Dwarfs' mine.", "minHeight": 38, "latitude": 28.4215, "longitude": -81.5818},
      {"id": 126, "parkId": 6, "name": "The Barnstormer", "type": "coaster", "description": "Join the Great Goofini on a junior roller coaster.", "minHeight": 35, "latitude": 28.4205, "longitude": -81.5779},
      {"id": 142, "parkId": 6, "name": "The Many Adventures of Winnie the Pooh", "type": "darkride", "description": "Journey through the Hundred-Acre Wood in a giant Hunny Pot.", "minHeight": null, "latitude": 28.4200, "longitude": -81.5812},
      {"id": 127, "parkId": 6, "name": "Under the Sea - Journey of The Little Mermaid", "type": "darkride", "description": "Journey under the sea with Ariel and her friends.", "minHeight": null, "latitude": 28.4212, "longitude": -81.5815},
      {"id": 1181, "parkId": 6, "name": "Walt Disney World Railroad - Fantasyland", "type": "train", "description": "Take a grand circle tour of the Magic Kingdom aboard an authentic steam-powered train.", "minHeight": null, "latitude": 28.4185, "longitude": -81.5865},
      {"id": 130, "parkId": 6, "name": "Big Thunder Mountain Railroad", "type": "coaster", "description": "The wildest ride in the wilderness!", "minHeight": 40, "latitude": 28.4194, "longitude": -81.5835},
      {"id": 1214, "parkId": 6, "name": "Country Bear Musical Jamboree", "type": "show", "description": "Enjoy a comical concert featuring a cast of singing animatronic bears.", "minHeight": null, "latitude": 28.4178, "longitude": -81.5825},
      {"id": 13630, "parkId": 6, "name": "Tiana's Bayou Adventure", "type": "water", "description": "Float through a vibrant bayou celebration.", "minHeight": 40, "latitude": 28.4172, "longitude": -81.5847},
      {"id": 465, "parkId": 6, "name": "Tom Sawyer Island", "type": "boat", "description": "Cross the Rivers of America on a log raft to a rustic hideaway.", "minHeight": null, "latitude": 28.4168, "longitude": -81.5840},
      {"id": 1179, "parkId": 6, "name": "Walt Disney World Railroad - Frontierland", "type": "train", "description": "Take a grand circle tour of the Magic Kingdom aboard an authentic steam-powered train.", "minHeight": null, "latitude": 28.4185, "longitude": -81.5865},
      {"id": 140, "parkId": 6, "name": "Haunted Mansion", "type": "darkride", "description": "Climb aboard a Doom Buggy for a spooky tour through a haunted estate.", "minHeight": null, "latitude": 28.4179, "longitude": -81.5828},
      {"id": 1187, "parkId": 6, "name": "Liberty Square Riverboat", "type": "boat", "description": "Take a scenic journey on a steam-powered paddle wheeler.", "minHeight": null, "latitude": 28.4165, "longitude": -81.5840},
      {"id": 356, "parkId": 6, "name": "The Hall of Presidents", "type": "show", "description": "Behold all Presidents of the United States in a stirring Audio-Animatronics show.", "minHeight": null, "latitude": 28.4179, "longitude": -81.5830},
      {"id": 1188, "parkId": 6, "name": "Main Street Vehicles", "type": "car", "description": "Ride in a classic vehicle down Main Street, U.S.A.", "minHeight": null, "latitude": 28.418, "longitude": -81.581},
      {"id": 146, "parkId": 6, "name": "Meet Mickey at Town Square Theater", "type": "meet", "description": "Meet Mickey Mouse at Town Square Theater.", "minHeight": null, "latitude": 28.4145, "longitude": -81.5805},
      {"id": 1189, "parkId": 6, "name": "Walt Disney World Railroad - Main Street, U.S.A.", "type": "train", "description": "Take a grand circle tour of the Magic Kingdom aboard an authentic steam-powered train.", "minHeight": null, "latitude": 28.4150, "longitude": -81.5805},
      {"id": 248, "parkId": 6, "name": "Astro Orbiter", "type": "spinner", "description": "Pilot your own spaceship high above Tomorrowland.", "minHeight": null, "latitude": 28.4192, "longitude": -81.5795},
      {"id": 131, "parkId": 6, "name": "Buzz Lightyear's Space Ranger Spin", "type": "shooter", "description": "Zap Zurg and his minions with your laser cannon.", "minHeight": null, "latitude": 28.4185, "longitude": -81.5797},
      {"id": 125, "parkId": 6, "name": "Monsters Inc. Laugh Floor", "type": "show", "description": "Enjoy a hilarious, interactive comedy show featuring Mike Wazowski.", "minHeight": null, "latitude": 28.4180, "longitude": -81.5785},
      {"id": 138, "parkId": 6, "name": "Space Mountain", "type": "coaster", "description": "Blast off on a high-speed adventure through deep space.", "minHeight": 44, "latitude": 28.4189, "longitude": -81.5794},
      {"id": 143, "parkId": 6, "name": "Tomorrowland Speedway", "type": "car", "description": "Take the wheel of a gas-powered car and cruise along a scenic miniature motorway.", "minHeight": 32, "latitude": 28.4175, "longitude": -81.5800},
      {"id": 1190, "parkId": 6, "name": "Tomorrowland Transit Authority PeopleMover", "type": "experience", "description": "Board a slow-moving tram for a narrated journey through Tomorrowland.", "minHeight": null, "latitude": 28.4185, "longitude": -81.5797},
      {"id": 11527, "parkId": 6, "name": "TRON Lightcycle / Run", "type": "coaster", "description": "Race through the Grid on a thrilling semi-enclosed roller coaster.", "minHeight": 48, "latitude": 28.4198, "longitude": -81.5790},
      {"id": 457, "parkId": 6, "name": "Walt Disney's Carousel of Progress", "type": "show", "description": "Revolve through the 20th century to see how technology has improved family life.", "minHeight": null, "latitude": 28.4182, "longitude": -81.5792},
    {"id": 13773, "parkId": 5, "name": "American Heritage Gallery", "type": "show", "description": "Explore American history and culture through exhibits.", "minHeight": null, "latitude": 28.373, "longitude": -81.549},
    {"id": 13778, "parkId": 5, "name": "Kidcot Fun Stops", "type": "experience", "description": "Interactive craft stations for kids in World Showcase.", "minHeight": null, "latitude": 28.373, "longitude": -81.549},
    {"id": 13779, "parkId": 5, "name": "Palais du Cinéma", "type": "show", "description": "French cinema and cultural exhibits.", "minHeight": null, "latitude": 28.370, "longitude": -81.547},
    {"id": 13777, "parkId": 5, "name": "ImageWorks - The \\"What If\\" Labs", "type": "experience", "description": "Interactive play area for kids and families.", "minHeight": null, "latitude": 28.374, "longitude": -81.551},
    {"id": 13781, "parkId": 5, "name": "Bijutsu-kan Gallery", "type": "show", "description": "Japanese art and culture exhibits.", "minHeight": null, "latitude": 28.370, "longitude": -81.547},
    {"id": 2495, "parkId": 5, "name": "Disney and Pixar Short Film Festival", "type": "show", "description": "A 4D film festival featuring Disney and Pixar shorts.", "minHeight": null, "latitude": 28.375, "longitude": -81.549},
    {"id": 155, "parkId": 5, "name": "Journey Into Imagination With Figment", "type": "darkride", "description": "A whimsical dark ride through your imagination.", "minHeight": null, "latitude": 28.3745, "longitude": -81.5510},
    {"id": 13627, "parkId": 5, "name": "Meet Beloved Disney Pals at Mickey & Friends", "type": "meet", "description": "Meet Mickey and friends in World Celebration.", "minHeight": null, "latitude": 28.375, "longitude": -81.549},
    {"id": 13775, "parkId": 5, "name": "Project Tomorrow: Inventing the Wonders of the Future", "type": "experience", "description": "Interactive exhibits about the future of technology.", "minHeight": null, "latitude": 28.375, "longitude": -81.549},
    {"id": 159, "parkId": 5, "name": "Spaceship Earth", "type": "darkride", "description": "A gentle, inspiring dark ride through the history of communication.", "minHeight": null, "latitude": 28.3750, "longitude": -81.5495},
    {"id": 13774, "parkId": 5, "name": "Advanced Training Lab", "type": "experience", "description": "Interactive space-themed play area.", "minHeight": null, "latitude": 28.376, "longitude": -81.550},
    {"id": 10916, "parkId": 5, "name": "Guardians of the Galaxy: Cosmic Rewind", "type": "coaster", "description": "A high-speed indoor roller coaster with rotating cars.", "minHeight": 42, "latitude": 28.3747, "longitude": -81.5492},
    {"id": 158, "parkId": 5, "name": "Mission: SPACE", "type": "simulator", "description": "Train for your own mission to Mars on this intense shuttle simulator.", "minHeight": 40, "latitude": 28.3759, "longitude": -81.5499},
    {"id": 160, "parkId": 5, "name": "Test Track", "type": "coaster", "description": "Design a virtual concept car and take it for a high-octane spin.", "minHeight": 40, "latitude": 28.3752, "longitude": -81.5471},
    {"id": 7323, "parkId": 5, "name": "Awesome Planet", "type": "show", "description": "A film about Earth's beauty and diversity.", "minHeight": null, "latitude": 28.3748, "longitude": -81.5508},
    {"id": 13770, "parkId": 5, "name": "Bruce's Shark World", "type": "experience", "description": "Interactive play area themed to Finding Nemo.", "minHeight": null, "latitude": 28.376, "longitude": -81.549},
    {"id": 12387, "parkId": 5, "name": "Journey of Water, Inspired by Moana", "type": "experience", "description": "Outdoor water play area inspired by Moana.", "minHeight": null, "latitude": 28.375, "longitude": -81.550},
    {"id": 156, "parkId": 5, "name": "Living with the Land", "type": "boat", "description": "Sail through the greenhouses of The Land pavilion.", "minHeight": null, "latitude": 28.3750, "longitude": -81.5505},
    {"id": 13782, "parkId": 5, "name": "SeaBase Aquarium", "type": "experience", "description": "Explore a large saltwater aquarium.", "minHeight": null, "latitude": 28.376, "longitude": -81.549},
    {"id": 151, "parkId": 5, "name": "Soarin' Around the World", "type": "simulator", "description": "Soar over global landmarks on this breathtaking hang-gliding simulator.", "minHeight": 40, "latitude": 28.3754, "longitude": -81.5492},
    {"id": 153, "parkId": 5, "name": "The Seas with Nemo & Friends", "type": "darkride", "description": "Board a 'clammobile' and journey under the sea with Nemo, Marlin, and Dory.", "minHeight": null, "latitude": 28.3765, "longitude": -81.5495},
    {"id": 152, "parkId": 5, "name": "Turtle Talk With Crush", "type": "show", "description": "Interactive show with Crush the turtle.", "minHeight": null, "latitude": 28.376, "longitude": -81.549},
    {"id": 829, "parkId": 5, "name": "Canada Far and Wide in Circle-Vision 360", "type": "show", "description": "A Circle-Vision 360 film showcasing the beauty and diversity of Canada.", "minHeight": null, "latitude": 28.3645, "longitude": -81.5490},
    {"id": 2679, "parkId": 5, "name": "Frozen Ever After", "type": "boat", "description": "Embark on a musical boat ride through the wintery world of Arendelle.", "minHeight": null, "latitude": 28.3687, "longitude": -81.5489},
    {"id": 13772, "parkId": 5, "name": "Gallery of Arts and History", "type": "show", "description": "Cultural exhibits in World Showcase.", "minHeight": null, "latitude": 28.369, "longitude": -81.549},
    {"id": 466, "parkId": 5, "name": "Gran Fiesta Tour Starring The Three Caballeros", "type": "boat", "description": "A gentle boat ride through Mexico with The Three Caballeros.", "minHeight": null, "latitude": 28.3695, "longitude": -81.5495},
    {"id": 13767, "parkId": 5, "name": "House of the Whispering Willows", "type": "show", "description": "Chinese art and culture exhibits.", "minHeight": null, "latitude": 28.368, "longitude": -81.548},
    {"id": 6701, "parkId": 5, "name": "Meet Anna and Elsa at Royal Sommerhus", "type": "meet", "description": "Meet Anna and Elsa in Norway Pavilion.", "minHeight": null, "latitude": 28.369, "longitude": -81.548},
    {"id": 13780, "parkId": 5, "name": "Mexico Folk Art Gallery", "type": "show", "description": "Mexican folk art exhibits.", "minHeight": null, "latitude": 28.369, "longitude": -81.549},
    {"id": 10914, "parkId": 5, "name": "Remy's Ratatouille Adventure", "type": "darkride", "description": "Shrink down to the size of a rat for a 4D culinary adventure.", "minHeight": null, "latitude": 28.3707, "longitude": -81.5469},
    {"id": 10915, "parkId": 5, "name": "Remy's Ratatouille Adventure Single Rider", "type": "darkride", "description": "Single rider line for Remy's Ratatouille Adventure.", "minHeight": null, "latitude": 28.3707, "longitude": -81.5469},
    {"id": 13776, "parkId": 5, "name": "Stave Church Gallery", "type": "show", "description": "Norwegian culture and history exhibits.", "minHeight": null, "latitude": 28.369, "longitude": -81.548},
    {"id": 12430, "parkId": 7, "name": "Meet Ariel at Walt Disney Presents", "type": "meet", "description": "Meet Ariel in Animation Courtyard.", "minHeight": null, "latitude": 28.357, "longitude": -81.558},
    {"id": 2478, "parkId": 7, "name": "Star Wars Launch Bay", "type": "experience", "description": "Star Wars exhibits and meet & greets.", "minHeight": null, "latitude": 28.357, "longitude": -81.558},
    {"id": 2663, "parkId": 7, "name": "Star Wars Launch Bay Theater", "type": "show", "description": "Short film about Star Wars.", "minHeight": null, "latitude": 28.357, "longitude": -81.558},
    {"id": 6705, "parkId": 7, "name": "Star Wars Launch Bay: BB-8 Astromech on Duty", "type": "meet", "description": "Meet BB-8 in Star Wars Launch Bay.", "minHeight": null, "latitude": 28.357, "longitude": -81.558},
    {"id": 2574, "parkId": 7, "name": "Star Wars Launch Bay: Encounter Darth Vader", "type": "meet", "description": "Meet Darth Vader in Star Wars Launch Bay.", "minHeight": null, "latitude": 28.357, "longitude": -81.558},
    {"id": 2577, "parkId": 7, "name": "Star Wars Launch Bay: Meet Chewbacca", "type": "meet", "description": "Meet Chewbacca in Star Wars Launch Bay.", "minHeight": null, "latitude": 28.357, "longitude": -81.558},
    {"id": 5145, "parkId": 7, "name": "Walt Disney Presents", "type": "show", "description": "Exhibits and film about Walt Disney.", "minHeight": null, "latitude": 28.357, "longitude": -81.556},
    {"id": 6704, "parkId": 7, "name": "Meet Disney Stars at Red Carpet Dreams", "type": "meet", "description": "Meet Disney stars at Red Carpet Dreams.", "minHeight": null, "latitude": 28.357, "longitude": -81.557},
    {"id": 1174, "parkId": 7, "name": "For the First Time in Forever: A Frozen Sing-Along Celebration", "type": "show", "description": "Sing along with Anna, Elsa, and Kristoff.", "minHeight": null, "latitude": 28.358, "longitude": -81.557},
    {"id": 6702, "parkId": 7, "name": "Indiana Jones™ Epic Stunt Spectacular!", "type": "show", "description": "Live-action stunt show with Indiana Jones.", "minHeight": null, "latitude": 28.3565, "longitude": -81.5585},
    {"id": 6703, "parkId": 7, "name": "Meet Olaf at Celebrity Spotlight", "type": "meet", "description": "Meet Olaf from Frozen.", "minHeight": null, "latitude": 28.358, "longitude": -81.557},
    {"id": 120, "parkId": 7, "name": "Star Tours – The Adventures Continue", "type": "simulator", "description": "A 3D motion-simulated space flight to popular destinations from the Star Wars films.", "minHeight": 40, "latitude": 28.356, "longitude": -81.559},
    {"id": 7333, "parkId": 7, "name": "Vacation Fun - An Original Animated Short with Mickey & Minnie", "type": "show", "description": "Animated short film with Mickey & Minnie.", "minHeight": null, "latitude": 28.358, "longitude": -81.557},
    {"id": 6361, "parkId": 7, "name": "Mickey & Minnie's Runaway Railway", "type": "darkride", "description": "Take a ride on a runaway railway through a cartoon world.", "minHeight": null, "latitude": 28.3579, "longitude": -81.5593},
    {"id": 12425, "parkId": 7, "name": "Meet Edna Mode at the Edna Mode Experience", "type": "meet", "description": "Meet Edna Mode from The Incredibles.", "minHeight": null, "latitude": 28.358, "longitude": -81.558},
    {"id": 117, "parkId": 7, "name": "Toy Story Mania!", "type": "shooter", "description": "An interactive 4D shooting-gallery ride starring your favorite Toy Story characters.", "minHeight": null, "latitude": 28.359, "longitude": -81.56},
    {"id": 6368, "parkId": 7, "name": "Millennium Falcon: Smugglers Run", "type": "simulator", "description": "Pilot the Millennium Falcon on a thrilling interactive mission.", "minHeight": 38, "latitude": 28.3551, "longitude": -81.5592},
    {"id": 10902, "parkId": 7, "name": "Millennium Falcon: Smugglers Run Single Rider", "type": "simulator", "description": "Single rider line for Millennium Falcon: Smugglers Run.", "minHeight": 38, "latitude": 28.3551, "longitude": -81.5592},
    {"id": 6369, "parkId": 7, "name": "Star Wars: Rise of the Resistance", "type": "darkride", "description": "Join the Resistance in an epic, multi-platform battle against the First Order.", "minHeight": 40, "latitude": 28.3551, "longitude": -81.5592},
    {"id": 14531, "parkId": 7, "name": "Star Wars: Rise of the Resistance Single Rider", "type": "darkride", "description": "Single rider line for Rise of the Resistance.", "minHeight": 40, "latitude": 28.3551, "longitude": -81.5592},
    {"id": 1176, "parkId": 7, "name": "Beauty and the Beast – Live on Stage", "type": "show", "description": "Broadway-style musical show.", "minHeight": null, "latitude": 28.355, "longitude": -81.555},
    {"id": 119, "parkId": 7, "name": "Rock 'n' Roller Coaster Starring Aerosmith", "type": "coaster", "description": "Race through L.A. in a super-stretch limo to the driving beat of rock and roll.", "minHeight": 48, "latitude": 28.3575, "longitude": -81.5574},
    {"id": 10901, "parkId": 7, "name": "Rock 'n' Roller Coaster Starring Aerosmith Single Rider", "type": "coaster", "description": "Single rider line for Rock 'n' Roller Coaster.", "minHeight": 48, "latitude": 28.3575, "longitude": -81.5574},
    {"id": 123, "parkId": 7, "name": "The Twilight Zone Tower of Terror™", "type": "drop", "description": "Plummet 13 stories in a haunted elevator shaft.", "minHeight": 40, "latitude": 28.3562, "longitude": -81.5562},
    {"id": 5477, "parkId": 7, "name": "Alien Swirling Saucers", "type": "spinner", "description": "Spin around in a toy saucer with Buzz and Woody.", "minHeight": 32, "latitude": 28.358, "longitude": -81.559},
    {"id": 5476, "parkId": 7, "name": "Slinky Dog Dash", "type": "coaster", "description": "A family-friendly coaster that twists and turns through Andy's backyard.", "minHeight": 38, "latitude": 28.3585, "longitude": -81.5595},
    {"id": 657, "parkId": 8, "name": "Festival of the Lion King", "type": "show", "description": "A spectacular Broadway-style show filled with songs, pageantry, and puppetry from The Lion King.", "minHeight": null, "latitude": 28.3619, "longitude": -81.5932},
    {"id": 651, "parkId": 8, "name": "Gorilla Falls Exploration Trail", "type": "experience", "description": "Explore a lush walking trail featuring gorillas, hippos, and other African wildlife.", "minHeight": null, "latitude": 28.3610, "longitude": -81.5940},
    {"id": 113, "parkId": 8, "name": "Kilimanjaro Safaris", "type": "safari", "description": "Climb aboard an open-air vehicle for a guided tour of a lush African savanna.", "minHeight": null, "latitude": 28.3627, "longitude": -81.5930},
    {"id": 655, "parkId": 8, "name": "Wildlife Express Train", "type": "train", "description": "Take a rustic steam train to Rafiki's Planet Watch, an area dedicated to conservation.", "minHeight": null, "latitude": 28.3625, "longitude": -81.5960},
    {"id": 110, "parkId": 8, "name": "Expedition Everest - Legend of the Forbidden Mountain", "type": "coaster", "description": "Race through the Himalayas on a speeding train to escape the legendary Yeti.", "minHeight": 44, "latitude": 28.3582, "longitude": -81.5888},
    {"id": 14533, "parkId": 8, "name": "Expedition Everest - Legend of the Forbidden Mountain Single Rider", "type": "coaster", "description": "Single rider line for Expedition Everest.", "minHeight": 44, "latitude": 28.3582, "longitude": -81.5888},
    {"id": 10921, "parkId": 8, "name": "Feathered Friends in Flight!", "type": "show", "description": "Live bird show featuring free-flying birds.", "minHeight": null, "latitude": 28.357, "longitude": -81.5883},
    {"id": 112, "parkId": 8, "name": "Kali River Rapids", "type": "water", "description": "Get soaked on a thrilling whitewater raft adventure through a lush jungle.", "minHeight": 38, "latitude": 28.3615, "longitude": -81.5891},
    {"id": 13809, "parkId": 8, "name": "Dino-Sue", "type": "experience", "description": "See a replica of the largest T-Rex ever discovered.", "minHeight": null, "latitude": 28.357, "longitude": -81.5878},
    {"id": 111, "parkId": 8, "name": "DINOSAUR", "type": "darkride", "description": "A thrilling and bumpy ride back in time to rescue a dinosaur before the meteor strikes.", "minHeight": 40, "latitude": 28.3558, "longitude": -81.5880},
    {"id": 10920, "parkId": 8, "name": "Finding Nemo: The Big Blue... and Beyond!", "type": "show", "description": "Dive into the heart of the ocean with this musical stage show.", "minHeight": null, "latitude": 28.3570, "longitude": -81.5883},
    {"id": 652, "parkId": 8, "name": "The Boneyard", "type": "experience", "description": "A dinosaur-themed playground for kids.", "minHeight": null, "latitude": 28.3565, "longitude": -81.5875},
    {"id": 13811, "parkId": 8, "name": "Discovery Island Trails", "type": "experience", "description": "Nature trails around the Tree of Life.", "minHeight": null, "latitude": 28.361, "longitude": -81.594},
    {"id": 116, "parkId": 8, "name": "Meet Favorite Disney Pals at Adventurers Outpost", "type": "meet", "description": "Meet Mickey and Minnie in their safari gear.", "minHeight": null, "latitude": 28.36, "longitude": -81.5905},
    {"id": 12451, "parkId": 8, "name": "Meet Moana at Character Landing", "type": "meet", "description": "Meet Moana in Discovery Island.", "minHeight": null, "latitude": 28.361, "longitude": -81.594},
    {"id": 13751, "parkId": 8, "name": "Tree of Life", "type": "experience", "description": "Iconic centerpiece of Animal Kingdom.", "minHeight": null, "latitude": 28.358, "longitude": -81.591},
    {"id": 4439, "parkId": 8, "name": "Avatar Flight of Passage", "type": "simulator", "description": "Fly on the back of a banshee on a breathtaking 3D ride over the world of Pandora.", "minHeight": 44, "latitude": 28.355, "longitude": -81.5913},
    {"id": 4438, "parkId": 8, "name": "Na'vi River Journey", "type": "boat", "description": "A gentle and mystical boat ride through a bioluminescent rainforest.", "minHeight": null, "latitude": 28.3548, "longitude": -81.5910},
    {"id": 13807, "parkId": 8, "name": "Affection Section", "type": "experience", "description": "Petting zoo at Rafiki's Planet Watch.", "minHeight": null, "latitude": 28.362, "longitude": -81.596},
    {"id": 13806, "parkId": 8, "name": "Conservation Station", "type": "experience", "description": "Learn about animal care and conservation.", "minHeight": null, "latitude": 28.362, "longitude": -81.596},
    {"id": 6680, "parkId": 8, "name": "The Animation Experience at Conservation Station", "type": "show", "description": "Learn to draw Disney characters.", "minHeight": null, "latitude": 28.362, "longitude": -81.596},
    {"id": 13812, "parkId": 8, "name": "The Oasis Exhibits", "type": "experience", "description": "Animal exhibits at the park entrance.", "minHeight": null, "latitude": 28.358, "longitude": -81.593},
    {"id": 13808, "parkId": 8, "name": "Wilderness Explorers", "type": "experience", "description": "Interactive scavenger hunt for kids.", "minHeight": null, "latitude": 28.358, "longitude": -81.593},
    {"id": 6008, "parkId": 64, "name": "Camp Jurassic™", "type": "experience", "description": "A prehistoric-themed play area for kids.", "minHeight": null, "latitude": 28.473, "longitude": -81.468},
    {"id": 6012, "parkId": 64, "name": "Jurassic Park Discovery Center™", "type": "experience", "description": "Interactive exhibits and dinosaur fun.", "minHeight": null, "latitude": 28.474, "longitude": -81.468},
    {"id": 5994, "parkId": 64, "name": "Jurassic Park River Adventure™", "type": "water", "description": "Enjoy a scenic water tour that culminates in an 85-foot plunge to escape a T-rex.", "minHeight": 42, "latitude": 28.4735, "longitude": -81.4695},
    {"id": 8721, "parkId": 64, "name": "Jurassic World VelociCoaster", "type": "coaster", "description": "Hunt for raptors on this high-speed launch coaster.", "minHeight": 51, "latitude": 28.4740, "longitude": -81.4680},
    {"id": 13109, "parkId": 64, "name": "Jurassic World VelociCoaster Single Rider", "type": "coaster", "description": "Single rider line for VelociCoaster.", "minHeight": 51, "latitude": 28.4740, "longitude": -81.4680},
    {"id": 5999, "parkId": 64, "name": "Pteranodon Flyers™", "type": "spinner", "description": "Fly high above Jurassic Park on a suspended glider ride.", "minHeight": 36, "latitude": 28.4745, "longitude": -81.4686},
    {"id": 6017, "parkId": 64, "name": "Skull Island: Reign of Kong™", "type": "darkride", "description": "A thrilling dark ride through Skull Island.", "minHeight": 36, "latitude": 28.473, "longitude": -81.469},
    {"id": 5988, "parkId": 64, "name": "Doctor Doom's Fearfall®", "type": "drop", "description": "Experience a sudden and intense drop from the top of Doctor Doom's tower.", "minHeight": 52, "latitude": 28.4723, "longitude": -81.4714},
    {"id": 6003, "parkId": 64, "name": "Storm Force Accelatron®", "type": "spinner", "description": "Spin rapidly on this high-energy carnival ride themed to the X-Men's Storm.", "minHeight": null, "latitude": 28.4726, "longitude": -81.471},
    {"id": 5985, "parkId": 64, "name": "The Amazing Adventures of Spider-Man®", "type": "darkride", "description": "Join Spider-Man in a thrilling 3D adventure battling villains.", "minHeight": 40, "latitude": 28.4729, "longitude": -81.4711},
    {"id": 6004, "parkId": 64, "name": "The Incredible Hulk Coaster®", "type": "coaster", "description": "Launch at incredible speeds and twist through inversions.", "minHeight": 54, "latitude": 28.4719, "longitude": -81.4717},
    {"id": 5986, "parkId": 64, "name": "Caro-Seuss-el™", "type": "carousel", "description": "Spin around on a colorful carousel featuring beloved Seuss characters.", "minHeight": null, "latitude": 28.4702, "longitude": -81.4678},
    {"id": 6011, "parkId": 64, "name": "If I Ran The Zoo™", "type": "experience", "description": "Interactive play area for kids.", "minHeight": null, "latitude": 28.470, "longitude": -81.468},
    {"id": 5997, "parkId": 64, "name": "One Fish, Two Fish, Red Fish, Blue Fish™", "type": "spinner", "description": "Spin around in a colorful fish-shaped vehicle.", "minHeight": null, "latitude": 28.4695, "longitude": -81.4682},
    {"id": 5987, "parkId": 64, "name": "The Cat in The Hat™", "type": "darkride", "description": "Journey through the classic Dr. Seuss story in this whimsical dark ride.", "minHeight": 36, "latitude": 28.4698, "longitude": -81.4680},
    {"id": 6001, "parkId": 64, "name": "The High in the Sky Seuss Trolley Train Ride!™", "type": "train", "description": "Take a scenic journey high above Seuss Landing on a colorful trolley.", "minHeight": 36, "latitude": 28.4700, "longitude": -81.4675},
    {"id": 5991, "parkId": 64, "name": "Flight of the Hippogriff™", "type": "coaster", "description": "A family-friendly roller coaster that flies you around Hagrid's hut.", "minHeight": 36, "latitude": 28.4708, "longitude": -81.4692},
    {"id": 6682, "parkId": 64, "name": "Hagrid's Magical Creatures Motorbike Adventure™", "type": "coaster", "description": "Experience a thrilling motorbike coaster adventure through the Forbidden Forest.", "minHeight": 48, "latitude": 28.4709, "longitude": -81.4699},
    {"id": 5992, "parkId": 64, "name": "Harry Potter and the Forbidden Journey™", "type": "darkride", "description": "Soar above the Hogwarts castle grounds on a magical bench.", "minHeight": 48, "latitude": 28.4706, "longitude": -81.4696},
    {"id": 6015, "parkId": 64, "name": "Hogwarts™ Express - Hogsmeade™ Station", "type": "train", "description": "Ride the famous train from Hogsmeade Station to King's Cross Station.", "minHeight": null, "latitude": 28.4711, "longitude": -81.4695},
    {"id": 13098, "parkId": 64, "name": "Ollivanders™ Experience in Hogsmeade™", "type": "experience", "description": "Interactive wand experience in Hogsmeade.", "minHeight": null, "latitude": 28.471, "longitude": -81.469},
    {"id": 5989, "parkId": 64, "name": "Dudley Do-Right's Ripsaw Falls®", "type": "water", "description": "Take a hilarious and soaking log flume journey.", "minHeight": 44, "latitude": 28.4735, "longitude": -81.4695},
    {"id": 6013, "parkId": 64, "name": "Me Ship, The Olive®", "type": "experience", "description": "Play area for kids themed to Popeye.", "minHeight": null, "latitude": 28.474, "longitude": -81.469},
    {"id": 5998, "parkId": 64, "name": "Popeye & Bluto's Bilge-Rat Barges®", "type": "water", "description": "Navigate treacherous rapids and splash down on this soaking river raft ride.", "minHeight": 42, "latitude": 28.4733, "longitude": -81.4690},
    {"id": 13605, "parkId": 65, "name": "Hollywood Rip Ride Rockit", "type": "coaster", "description": "A high-speed roller coaster with a vertical lift and customizable soundtrack.", "minHeight": 51, "latitude": 28.4755, "longitude": -81.4696},
    {"id": 6018, "parkId": 65, "name": "Despicable Me Minion Mayhem", "type": "simulator", "description": "Join the Minions on a wild 3D simulator ride.", "minHeight": 40, "latitude": 28.4760, "longitude": -81.4690},
    {"id": 12107, "parkId": 65, "name": "TRANSFORMERS: The Ride-3D", "type": "darkride", "description": "An immersive 3D dark ride battling alongside the Autobots.", "minHeight": 40, "latitude": 28.4750, "longitude": -81.4685},
    {"id": 6021, "parkId": 65, "name": "Race Through New York Starring Jimmy Fallon", "type": "simulator", "description": "A 3D motion-simulator ride through New York City.", "minHeight": 40, "latitude": 28.4768, "longitude": -81.4679},
    {"id": 6022, "parkId": 65, "name": "Revenge of the Mummy", "type": "coaster", "description": "An indoor roller coaster with intense special effects.", "minHeight": 48, "latitude": 28.4765, "longitude": -81.4675},
    {"id": 5984, "parkId": 65, "name": "MEN IN BLACK™ Alien Attack™", "type": "shooter", "description": "An interactive shooter ride where you zap aliens to become a full-fledged MIB agent.", "minHeight": 42, "latitude": 28.4780, "longitude": -81.4690},
    {"id": 6039, "parkId": 65, "name": "The Simpsons Ride™", "type": "simulator", "description": "A motion simulator ride through Krustyland with The Simpsons.", "minHeight": 40, "latitude": 28.4785, "longitude": -81.4695},
    {"id": 13110, "parkId": 65, "name": "Kang & Kodos' Twirl 'n' Hurl", "type": "spinner", "description": "A spinning ride hosted by the hilarious aliens from The Simpsons.", "minHeight": null, "latitude": 28.4783, "longitude": -81.4698},
    {"id": 13111, "parkId": 65, "name": "E.T. Adventure", "type": "darkride", "description": "Fly on a bicycle to help E.T. save his home planet.", "minHeight": 34, "latitude": 28.4790, "longitude": -81.4700},
    {"id": 6000, "parkId": 65, "name": "Harry Potter and the Escape from Gringotts™", "type": "coaster", "description": "A 3D dark ride and roller coaster hybrid adventure.", "minHeight": 42, "latitude": 28.4775, "longitude": -81.4710},
    {"id": 6016, "parkId": 65, "name": "Hogwarts™ Express - King's Cross Station", "type": "train", "description": "Travel from London to Hogsmeade™ on the iconic steam train.", "minHeight": null, "latitude": 28.4770, "longitude": -81.4715},
    {"id": 6025, "parkId": 65, "name": "The Bourne Stuntacular", "type": "show", "description": "A cutting-edge live-action stunt show.", "minHeight": null, "latitude": 28.4740, "longitude": -81.4670},
    {"id": 6026, "parkId": 65, "name": "Universal Orlando's Horror Make-Up Show", "type": "show", "description": "A hilarious and informative show about movie make-up and special effects.", "minHeight": null, "latitude": 28.4745, "longitude": -81.4665},
    {"id": 6038, "parkId": 65, "name": "Fast & Furious – Supercharged", "type": "darkride", "description": "A high-octane dark ride experience with the Fast & Furious crew.", "minHeight": 40, "latitude": 28.4795, "longitude": -81.4720},
    {"id": 14688, "parkId": 334, "name": "Constellation Carousel", "type": "carousel", "description": "A grand carousel at the heart of Celestial Park.", "minHeight": null, "latitude": 28.4601, "longitude": -81.4801},
    {"id": 14690, "parkId": 334, "name": "Stardust Racers", "type": "coaster", "description": "A high-speed dual-launch racing coaster.", "minHeight": 48, "latitude": 28.4600, "longitude": -81.4800},
    {"id": 14740, "parkId": 334, "name": "Stardust Racers Single Rider", "type": "coaster", "description": "Single rider line for Stardust Racers.", "minHeight": 48, "latitude": 28.4600, "longitude": -81.4800},
    {"id": 14692, "parkId": 334, "name": "Curse of the Werewolf", "type": "darkride", "description": "A thrilling dark ride and coaster combination through a haunted European village.", "minHeight": 40, "latitude": 28.4602, "longitude": -81.4802},
    {"id": 14698, "parkId": 334, "name": "Curse of the Werewolf Single Rider", "type": "darkride", "description": "Single rider line for Curse of the Werewolf.", "minHeight": 40, "latitude": 28.4602, "longitude": -81.4802},
    {"id": 14694, "parkId": 334, "name": "Monsters Unchained: The Frankenstein Experiment", "type": "show", "description": "A live show featuring Universal Monsters.", "minHeight": null, "latitude": 28.4603, "longitude": -81.4803},
    {"id": 14693, "parkId": 334, "name": "Dragon Racer's Rally", "type": "spinner", "description": "A spinning ride themed to How to Train Your Dragon.", "minHeight": null, "latitude": 28.4604, "longitude": -81.4804},
    {"id": 14691, "parkId": 334, "name": "Fyre Drill", "type": "experience", "description": "Interactive water play area in Isle of Berk.", "minHeight": null, "latitude": 28.4605, "longitude": -81.4805},
    {"id": 14695, "parkId": 334, "name": "Hiccup Wing Glider", "type": "coaster", "description": "A family coaster through the Isle of Berk.", "minHeight": 42, "latitude": 28.4606, "longitude": -81.4806},
    {"id": 14685, "parkId": 334, "name": "Meet Toothless and Friends", "type": "meet", "description": "Meet Toothless and other dragons.", "minHeight": null, "latitude": 28.4607, "longitude": -81.4807},
    {"id": 14682, "parkId": 334, "name": "Bowser Jr. Challenge", "type": "shooter", "description": "Interactive shooter ride in Super Nintendo World.", "minHeight": null, "latitude": 28.4608, "longitude": -81.4808},
    {"id": 14683, "parkId": 334, "name": "Mario Kart™: Bowser's Challenge", "type": "darkride", "description": "A Mario Kart-themed dark ride with AR elements.", "minHeight": 40, "latitude": 28.4609, "longitude": -81.4809},
    {"id": 14684, "parkId": 334, "name": "Mario Kart™: Bowser's Challenge Single Rider", "type": "darkride", "description": "Single rider line for Mario Kart: Bowser's Challenge.", "minHeight": 40, "latitude": 28.4609, "longitude": -81.4809},
    {"id": 14686, "parkId": 334, "name": "Mine-Cart Madness™", "type": "coaster", "description": "A thrilling mine cart coaster in Donkey Kong Country.", "minHeight": 36, "latitude": 28.4610, "longitude": -81.4810},
    {"id": 14697, "parkId": 334, "name": "Mine-Cart Madness™ Single Rider", "type": "coaster", "description": "Single rider line for Mine-Cart Madness.", "minHeight": 36, "latitude": 28.4610, "longitude": -81.4810},
    {"id": 14689, "parkId": 334, "name": "Yoshi's Adventure™", "type": "darkride", "description": "A family-friendly ride on Yoshi vehicles.", "minHeight": 36, "latitude": 28.4611, "longitude": -81.4811},
    {"id": 14687, "parkId": 334, "name": "Harry Potter and the Battle at the Ministry™", "type": "darkride", "description": "A Harry Potter-themed dark ride in Ministry of Magic.", "minHeight": null, "latitude": 28.4612, "longitude": -81.4812},
    {"id": 14696, "parkId": 334, "name": "Harry Potter and the Battle at the Ministry™ Single Rider", "type": "darkride", "description": "Single rider line for Harry Potter and the Battle at the Ministry.", "minHeight": null, "latitude": 28.4612, "longitude": -81.4812}
    ]
    """
}
