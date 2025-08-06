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
    
    // This mapping is now complete for every attraction in the JSON below.
    static let attractionToLandMapping: [Int: String] = [
        // Magic Kingdom (6)
        130: "Frontierland", 13630: "Frontierland", 128: "Frontierland",
        140: "Adventureland", 134: "Adventureland", 125: "Adventureland", 141: "Adventureland",
        137: "Liberty Square", 1214: "Liberty Square", 1187: "Liberty Square",
        138: "Fantasyland", 136: "Fantasyland", 355: "Fantasyland", 13764: "Fantasyland", 133: "Fantasyland", 135: "Fantasyland", 132: "Fantasyland", 126: "Fantasyland", 1184: "Fantasyland", 13763: "Fantasyland", 145: "Fantasyland", 6699: "Fantasyland", 6700: "Fantasyland", 144: "Fantasyland",
        129: "Tomorrowland", 11527: "Tomorrowland", 131: "Tomorrowland", 248: "Tomorrowland", 161: "Tomorrowland", 1188: "Tomorrowland", 334: "Tomorrowland", 356: "Tomorrowland", 171: "Tomorrowland",
        1179: "Fantasyland", 1189: "Frontierland", 1190: "Main Street, U.S.A.", 147: "Main Street, U.S.A.", 457: "Main Street, U.S.A.", 465: "Frontierland",
        
        // Epcot (5)
        160: "World Discovery", 10916: "World Discovery", 158: "World Discovery",
        151: "World Nature", 13775: "World Nature", 156: "World Nature", 13779: "World Nature",
        155: "World Celebration", 13770: "World Celebration",
        13778: "World Showcase", 153: "World Showcase", 13781: "World Showcase", 159: "World Showcase", 7323: "World Showcase", 13777: "World Showcase", 13627: "World Showcase", 13773: "World Showcase",
        
        // Hollywood Studios (7)
        14531: "Sunset Boulevard", 119: "Sunset Boulevard", 2663: "Sunset Boulevard",
        6368: "Toy Story Land", 117: "Toy Story Land", 10901: "Toy Story Land",
        6369: "Star Wars: Galaxy's Edge", 10902: "Star Wars: Galaxy's Edge",
        120: "Echo Lake", 1174: "Echo Lake", 7333: "Echo Lake",
        6361: "Hollywood Boulevard", 5145: "Grand Avenue", 118: "Animation Courtyard",
        
        // Animal Kingdom (8)
        110: "Asia", 112: "Asia",
        14533: "Pandora - The World of Avatar", 4438: "Pandora - The World of Avatar",
        111: "DinoLand U.S.A.", 652: "DinoLand U.S.A.", 13809: "DinoLand U.S.A.",
        651: "Africa", 657: "Africa", 655: "Africa", 13811: "Africa",
        10921: "Discovery Island", 10920: "Discovery Island", 116: "Discovery Island",
        
        // Universal Studios Florida (65)
        13605: "Production Central", 6018: "Production Central", 12107: "Production Central",
        5984: "New York",
        13110: "Springfield, U.S.A.", 13111: "Springfield, U.S.A.",
        6000: "The Wizarding World of Harry Potter - Diagon Alley", 6016: "The Wizarding World of Harry Potter - Diagon Alley",
        5990: "Woody Woodpecker's KidZone", 6014: "Woody Woodpecker's KidZone",
        6038: "San Francisco",
        
        // Islands of Adventure (64)
        5988: "Marvel Super Hero Island", 5985: "Marvel Super Hero Island", 5999: "Marvel Super Hero Island", 5986: "Marvel Super Hero Island",
        13109: "The Wizarding World of Harry Potter - Hogsmeade", 5987: "The Wizarding World of Harry Potter - Hogsmeade", 8721: "The Wizarding World of Harry Potter - Hogsmeade",
        90001: "Jurassic Park", 5997: "Jurassic Park", 6004: "Jurassic Park",
        6008: "Seuss Landing", 6017: "Seuss Landing", 6012: "Seuss Landing", 6003: "Seuss Landing",
        5994: "Toon Lagoon", 6011: "Toon Lagoon",
        
        // Epic Universe (334) -
        14690: "Celestial Park", 14692: "Dark Universe", 14693: "The Wizarding World of Harry Potter - Ministry of Magic", 14699: "How to Train Your Dragon - Isle of Berk", 14695: "Super Nintendo World", 14698: "Super Nintendo World", 14688: "Celestial Park", 14686: "Dark Universe"
    ]

    static func getSFならSymbol(for attractionId: Int) -> String {
        return attractionTypeToSymbol[attractionId] ?? "questionmark.circle.fill"
    }
    static let attractionTypeToSymbol: [Int: String] = [
        // Coasters
        130: "rollercoaster", 11527: "rollercoaster", 138: "rollercoaster", 126: "rollercoaster", 160: "rollercoaster", 5988: "rollercoaster", 13109: "rollercoaster", 90001: "rollercoaster", 14690: "rollercoaster", 14699: "rollercoaster", 14698: "rollercoaster", 13605: "rollercoaster", 6368: "rollercoaster", 119: "rollercoaster", 14531: "rollercoaster",
        // Water/Boat Rides
        13630: "drop.fill", 140: "ferry.fill", 134: "ferry.fill", 1187: "ferry.fill", 465: "ferry.fill", 112: "drop.fill", 5997: "drop.fill", 5994: "drop.fill", 6011: "lifepreserver.fill",
        // Dark Rides/Simulators
        129: "moon.stars.fill", 137: "moon.stars.fill", 136: "moon.stars.fill", 13764: "moon.stars.fill", 355: "moon.stars.fill", 133: "moon.stars.fill", 10916: "car.fill", 158: "airplane", 151: "airplane", 13770: "moon.stars.fill", 13778: "moon.stars.fill", 153: "moon.stars.fill", 156: "moon.stars.fill", 13775: "leaf.fill", 155: "paintbrush.pointed.fill", 13781: "ferry.fill", 159: "film.stack.fill", 7323: "film.stack.fill", 13779: "leaf.fill", 13773: "music.mic", 6369: "moon.stars.fill", 10902: "airplane", 6361: "moon.stars.fill", 120: "airplane", 5984: "moon.stars.fill", 6000: "wand.and.stars", 12107: "bolt.car.fill", 13110: "tv.and.hifispeaker.fill", 6018: "person.3.sequence.fill", 5990: "bicycle", 6038: "car.2.fill", 6014: "rollercoaster", 6016: "train.side.front.car", 90101: "theatermasks.fill", 90102: "wand.and.stars.inverse", 5987: "wand.and.stars", 5985: "camera.filters", 14692: "moon.stars.fill", 14693: "wand.and.stars", 14695: "gamecontroller.fill", 6008: "text.book.closed.fill", 6017: "tram.fill", 80001: "water.waves.and.arrow.up",
        // Spinners/Experiences
        135: "circle.grid.cross.fill", 132: "circle.grid.cross.fill", 248: "circle.grid.cross.fill", 141: "circle.grid.cross.fill", 6012: "circle.grid.cross.fill", 13763: "figure.walk.motion", 652: "circle.grid.cross.fill", 14688: "circle.grid.cross.fill",
        // Shooters/Interactive
        1188: "target", 117: "target",
        // Shows
        128: "music.mic", 125: "music.mic", 1184: "music.mic", 1214: "music.mic", 356: "music.mic", 171: "music.mic", 302: "music.mic", 1174: "music.mic", 5145: "theatermasks.circle.fill", 7333: "music.mic", 118: "music.mic", 657: "music.mic", 10921: "music.mic", 10920: "music.mic", 14686: "music.mic",
        // Meet & Greets
        147: "person.2.fill", 6699: "person.2.fill", 145: "person.2.fill", 6700: "person.2.fill", 144: "person.2.fill",
        // Parades/Experiences
        457: "scissors",
        // Misc
        161: "car.fill"
    ]
    
    private static let attractionsJSON = """
    [
      { "id": 130, "parkId": 6, "name": "Big Thunder Mountain Railroad", "type": "rollercoaster", "description": "The wildest ride in the wilderness!", "minHeight": 40, "latitude": 28.4194, "longitude": -81.5851 },
      { "id": 129, "parkId": 6, "name": "Space Mountain", "type": "moon.stars.fill", "description": "Blast off on a high-speed adventure through deep space.", "minHeight": 44, "latitude": 28.4189, "longitude": -81.5794 },
      { "id": 13630, "parkId": 6, "name": "Tiana's Bayou Adventure", "type": "drop.fill", "description": "Float through a vibrant bayou celebration.", "minHeight": 40, "latitude": 28.4172, "longitude": -81.5847 },
      { "id": 140, "parkId": 6, "name": "Jungle Cruise", "type": "ferry.fill", "description": "Embark on a guided tour down the rivers of the world.", "minHeight": null, "latitude": 28.4162, "longitude": -81.5862 },
      { "id": 137, "parkId": 6, "name": "Haunted Mansion", "type": "moon.stars.fill", "description": "Climb aboard a Doom Buggy for a spooky tour through a haunted estate.", "minHeight": null, "latitude": 28.4179, "longitude": -81.5828 },
      { "id": 11527, "parkId": 6, "name": "TRON Lightcycle / Run", "type": "rollercoaster", "description": "Race through the Grid on a thrilling semi-enclosed roller coaster.", "minHeight": 48, "latitude": 28.4198, "longitude": -81.5790 },
      { "id": 138, "parkId": 6, "name": "Seven Dwarfs Mine Train", "type": "rollercoaster", "description": "Embark on a daring quest to retrieve a diamond from the Seven Dwarfs' mine.", "minHeight": 38, "latitude": 28.4215, "longitude": -81.5818 },
      { "id": 133, "parkId": 6, "name": "Mickey's PhilharMagic", "type": "moon.stars.fill", "description": "A 3D movie extravaganza starring many favorite Disney characters.", "minHeight": null, "latitude": 28.4208, "longitude": -81.5800 },
      { "id": 134, "parkId": 6, "name": "Pirates of the Caribbean", "type": "ferry.fill", "description": "Set sail on a swashbuckling voyage through pirate-infested waters.", "minHeight": null, "latitude": 28.4168, "longitude": -81.5857 },
      { "id": 355, "parkId": 6, "name": "The Many Adventures of Winnie the Pooh", "type": "moon.stars.fill", "description": "Journey through the Hundred-Acre Wood in a giant Hunny Pot.", "minHeight": null, "latitude": 28.4200, "longitude": -81.5812 },
      { "id": 136, "parkId": 6, "name": "'it's a small world'", "type": "moon.stars.fill", "description": "Take a gentle boat tour and sing along with dolls from all over the globe.", "minHeight": null, "latitude": 28.4208, "longitude": -81.5807 },
      { "id": 13764, "parkId": 6, "name": "Under the Sea - Journey of The Little Mermaid", "type": "moon.stars.fill", "description": "Journey under the sea with Ariel and her friends.", "minHeight": null, "latitude": 28.4212, "longitude": -81.5815 },
      { "id": 135, "parkId": 6, "name": "Mad Tea Party", "type": "circle.grid.cross.fill", "description": "Spin ‘round and ‘round in a giant teacup.", "minHeight": null, "latitude": 28.4195, "longitude": -81.5805 },
      { "id": 132, "parkId": 6, "name": "Dumbo the Flying Elephant", "type": "circle.grid.cross.fill", "description": "Fly high above Fantasyland on a classic attraction.", "minHeight": null, "latitude": 28.4200, "longitude": -81.5800 },
      { "id": 126, "parkId": 6, "name": "The Barnstormer", "type": "rollercoaster", "description": "Join the Great Goofini on a junior roller coaster.", "minHeight": 35, "latitude": 28.4205, "longitude": -81.5779 },
      { "id": 161, "parkId": 6, "name": "Tomorrowland Speedway", "type": "car.fill", "description": "Take the wheel of a gas-powered car on a miniature motorway.", "minHeight": 32, "latitude": 28.4175, "longitude": -81.5800 },
      { "id": 1188, "parkId": 6, "name": "Buzz Lightyear's Space Ranger Spin", "type": "target", "description": "Zap Zurg and his minions with your laser cannon.", "minHeight": null, "latitude": 28.4185, "longitude": -81.5780 },
      { "id": 248, "parkId": 6, "name": "Astro Orbiter", "type": "circle.grid.cross.fill", "description": "Pilot your own spaceship high above Tomorrowland.", "minHeight": null, "latitude": 28.4192, "longitude": -81.5795 },
      { "id": 141, "parkId": 6, "name": "The Magic Carpets of Aladdin", "type": "circle.grid.cross.fill", "description": "Soar high above Adventureland on a gently flying magic carpet.", "minHeight": null, "latitude": 28.4140, "longitude": -81.5859 },
      { "id": 131, "parkId": 6, "name": "Tomorrowland Transit Authority PeopleMover", "type": "moon.stars.fill", "description": "Board a slow-moving tram for a narrated journey through Tomorrowland.", "minHeight": null, "latitude": 28.4185, "longitude": -81.5797 },
      { "id": 128, "parkId": 6, "name": "Country Bear Jamboree", "type": "music.mic", "description": "Enjoy a comical concert featuring a cast of singing animatronic bears.", "minHeight": null, "latitude": 28.4178, "longitude": -81.5825 },
      { "id": 125, "parkId": 6, "name": "Walt Disney's Enchanted Tiki Room", "type": "music.mic", "description": "Tropical birds and colorful flowers come to life in this classic musical show.", "minHeight": null, "latitude": 28.4155, "longitude": -81.5855 },
      { "id": 1184, "parkId": 6, "name": "Enchanted Tales with Belle", "type": "music.mic", "description": "Become part of a heartwarming story with Belle and Lumiere.", "minHeight": null, "latitude": 28.4210, "longitude": -81.5810 },
      { "id": 1214, "parkId": 6, "name": "The Hall of Presidents", "type": "music.mic", "description": "Behold all Presidents of the United States in a stirring Audio-Animatronics show.", "minHeight": null, "latitude": 28.4179, "longitude": -81.5830 },
      { "id": 356, "parkId": 6, "name": "Monsters, Inc. Laugh Floor", "type": "music.mic", "description": "Enjoy a hilarious, interactive comedy show featuring Mike Wazowski.", "minHeight": null, "latitude": 28.4180, "longitude": -81.5785 },
      { "id": 171, "parkId": 6, "name": "Walt Disney's Carousel of Progress", "type": "music.mic", "description": "Revolve through the 20th century to see how technology has improved family life.", "minHeight": null, "latitude": 28.4182, "longitude": -81.5792 },
      { "id": 1187, "parkId": 6, "name": "Liberty Square Riverboat", "type": "ferry.fill", "description": "Take a scenic journey on a steam-powered paddle wheeler.", "minHeight": null, "latitude": 28.4165, "longitude": -81.5840 },
      { "id": 465, "parkId": 6, "name": "Tom Sawyer Island", "type": "ferry.fill", "description": "Cross the Rivers of America on a log raft to a rustic hideaway.", "minHeight": null, "latitude": 28.4168, "longitude": -81.5840 },
      { "id": 13763, "parkId": 6, "name": "Prince Charming Regal Carrousel", "type": "sparkles", "description": "Enjoy a classic carousel ride in the heart of Fantasyland.", "minHeight": null, "latitude": 28.4195, "longitude": -81.5820 },
      { "id": 147, "parkId": 6, "name": "Town Square Theater", "type": "person.2.fill", "description": "Meet the one and only Mickey Mouse for a memorable photo.", "minHeight": null, "latitude": 28.4145, "longitude": -81.5805 },
      { "id": 6699, "parkId": 6, "name": "Meet Princesses at Princess Fairytale Hall", "type": "person.2.fill", "description": "Meet Princess Tiana and another royal friend.", "minHeight": null, "latitude": 28.4218, "longitude": -81.5820 },
      { "id": 145, "parkId": 6, "name": "Meet Cinderella and a Visiting Princess", "type": "person.2.fill", "description": "Meet Cinderella at this royal meet and greet location.", "minHeight": null, "latitude": 28.4218, "longitude": -81.5822 },
      { "id": 6700, "parkId": 6, "name": "Meet Rapunzel and a Visiting Princess", "type": "person.2.fill", "description": "Meet the charming Rapunzel in their fairytale setting.", "minHeight": null, "latitude": 28.4218, "longitude": -81.5825 },
      { "id": 144, "parkId": 6, "name": "Meet Tinker Bell", "type": "person.2.fill", "description": "Meet the magical pixie, Tinker Bell, for a photo and autograph.", "minHeight": null, "latitude": 28.4210, "longitude": -81.5810 },
      { "id": 334, "parkId": 6, "name": "Walt Disney's Carousel of Progress", "type": "music.mic", "description": "Revolve through the 20th century to see how technology has improved family life.", "minHeight": null, "latitude": 28.4190, "longitude": -81.5770 },
      { "id": 1179, "parkId": 6, "name": "Walt Disney World Railroad - Fantasyland", "type": "train.side.front.car", "description": "Take a grand circle tour of the Magic Kingdom aboard an authentic steam-powered train.", "minHeight": null, "latitude": 28.4185, "longitude": -81.5865 },
      { "id": 1189, "parkId": 6, "name": "Walt Disney World Railroad - Frontierland", "type": "train.side.front.car", "description": "Take a grand circle tour of the Magic Kingdom aboard an authentic steam-powered train.", "minHeight": null, "latitude": 28.4170, "longitude": -81.5845 },
      { "id": 1190, "parkId": 6, "name": "Walt Disney World Railroad - Main Street, U.S.A.", "type": "train.side.front.car", "description": "Take a grand circle tour of the Magic Kingdom aboard an authentic steam-powered train.", "minHeight": null, "latitude": 28.4150, "longitude": -81.5805 },
      { "id": 457, "parkId": 6, "name": "Harmony Barber Shop", "type": "scissors", "description": "Get a magical haircut or a pixie dust sprinkle at this charming old-fashioned barber shop.", "minHeight": null, "latitude": 28.4148, "longitude": -81.5800 },
      { "id": 160, "parkId": 5, "name": "Guardians of the Galaxy: Cosmic Rewind", "type": "sparkles", "description": "Join the Guardians of the Galaxy on an intergalactic chase through space and time.", "minHeight": 42, "latitude": 28.3747, "longitude": -81.5492 },
      { "id": 10916, "parkId": 5, "name": "Test Track", "type": "car.fill", "description": "Design a virtual concept car and take it for a high-octane spin.", "minHeight": 40, "latitude": 28.3752, "longitude": -81.5471 },
      { "id": 158, "parkId": 5, "name": "Mission: SPACE", "type": "airplane", "description": "Train for your own mission to Mars on this intense shuttle simulator.", "minHeight": 40, "latitude": 28.3759, "longitude": -81.5499 },
      { "id": 151, "parkId": 5, "name": "Soarin' Around the World", "type": "airplane", "description": "Soar over global landmarks on this breathtaking hang-gliding simulator.", "minHeight": 40, "latitude": 28.3754, "longitude": -81.5492 },
      { "id": 13770, "parkId": 5, "name": "Spaceship Earth", "type": "moon.stars.fill", "description": "A gentle, inspiring dark ride through the history of communication.", "minHeight": null, "latitude": 28.3750, "longitude": -81.5495 },
      { "id": 13778, "parkId": 5, "name": "Frozen Ever After", "type": "snowflake", "description": "Embark on a musical boat ride through the wintery world of Arendelle.", "minHeight": null, "latitude": 28.3687, "longitude": -81.5489 },
      { "id": 153, "parkId": 5, "name": "Remy's Ratatouille Adventure", "type": "camera.metering.matrix", "description": "Shrink down to the size of a rat for a 4D culinary adventure.", "minHeight": null, "latitude": 28.3707, "longitude": -81.5469 },
      { "id": 156, "parkId": 5, "name": "The Seas with Nemo & Friends", "type": "fish.fill", "description": "Board a 'clammobile' and journey under the sea with Nemo, Marlin, and Dory.", "minHeight": null, "latitude": 28.3765, "longitude": -81.5495 },
      { "id": 13775, "parkId": 5, "name": "Living with the Land", "type": "leaf.fill", "description": "Sail through the greenhouses of The Land pavilion to see how NASA technology is helping to grow crops.", "minHeight": null, "latitude": 28.3750, "longitude": -81.5505 },
      { "id": 155, "parkId": 5, "name": "Journey Into Imagination With Figment", "type": "paintbrush.pointed.fill", "description": "A whimsical dark ride through your imagination, led by the mischievous Figment.", "minHeight": null, "latitude": 28.3745, "longitude": -81.5510 },
      { "id": 13781, "parkId": 5, "name": "Gran Fiesta Tour Starring The Three Caballeros", "type": "ferry.fill", "description": "A gentle boat ride through Mexico with The Three Caballeros.", "minHeight": null, "latitude": 28.3695, "longitude": -81.5495 },
      { "id": 159, "parkId": 5, "name": "Impressions de France", "type": "film.stack.fill", "description": "Immerse yourself in the beauty and charm of France with this breathtaking film.", "minHeight": null, "latitude": 28.3705, "longitude": -81.5465 },
      { "id": 7323, "parkId": 5, "name": "Canada Far and Wide in Circle-Vision 360", "type": "film.stack.fill", "description": "A Circle-Vision 360 film showcasing the beauty and diversity of Canada.", "minHeight": null, "latitude": 28.3645, "longitude": -81.5490 },
      { "id": 13779, "parkId": 5, "name": "Awesome Planet", "type": "leaf.fill", "description": "Experience a breathtaking film showcasing the power and beauty of our planet.", "minHeight": null, "latitude": 28.3748, "longitude": -81.5508 },
      { "id": 13773, "parkId": 5, "name": "Beauty and the Beast Sing-Along", "type": "music.mic", "description": "Sing along with songs from the classic film in this special exhibit.", "minHeight": null, "latitude": 28.3707, "longitude": -81.5463 },
      { "id": 14531, "parkId": 7, "name": "The Twilight Zone Tower of Terror", "type": "arrow.down.to.line.alt", "description": "Plummet 13 stories in a haunted elevator shaft.", "minHeight": 40, "latitude": 28.3562, "longitude": -81.5562 },
      { "id": 119, "parkId": 7, "name": "Rock 'n' Roller Coaster Starring Aerosmith", "type": "rollercoaster", "description": "Race through L.A. in a super-stretch limo to the driving beat of rock and roll.", "minHeight": 48, "latitude": 28.3575, "longitude": -81.5574 },
      { "id": 6368, "parkId": 7, "name": "Slinky Dog Dash", "type": "rollercoaster", "description": "A family-friendly coaster that twists and turns through Andy's backyard.", "minHeight": 38, "latitude": 28.3585, "longitude": -81.5595 },
      { "id": 117, "parkId": 7, "name": "Toy Story Mania!", "type": "gamecontroller.fill", "description": "An interactive 4D shooting-gallery ride starring your favorite Toy Story characters.", "minHeight": null, "latitude": 28.3590, "longitude": -81.5600 },
      { "id": 6369, "parkId": 7, "name": "Star Wars: Rise of the Resistance", "type": "moon.stars.fill", "description": "Join the Resistance in an epic, multi-platform battle against the First Order.", "minHeight": 40, "latitude": 28.3551, "longitude": -81.5592 },
      { "id": 10902, "parkId": 7, "name": "Millennium Falcon: Smugglers Run", "type": "airplane", "description": "Fly the 'fastest hunk of junk in the galaxy' on a thrilling interactive smuggling mission.", "minHeight": 38, "latitude": 28.3547, "longitude": -81.5583 },
      { "id": 6361, "parkId": 7, "name": "Mickey & Minnie's Runaway Railway", "type": "train.side.middle.car", "description": "Take a ride on a runaway railway through a cartoon world.", "minHeight": null, "latitude": 28.3579, "longitude": -81.5593 },
      { "id": 120, "parkId": 7, "name": "Star Tours – The Adventures Continue", "type": "figure.seated.side", "description": "A 3D motion-simulated space flight to popular destinations from the Star Wars films.", "minHeight": 40, "latitude": 28.3560, "longitude": -81.5590 },
      { "id": 302, "parkId": 7, "name": "Beauty and the Beast Live on Stage", "type": "music.mic", "description": "Relive the tale as old as time in this Broadway-style stage production.", "minHeight": null, "latitude": 28.3550, "longitude": -81.5550 },
      { "id": 1174, "parkId": 7, "name": "Indiana Jones Epic Stunt Spectacular!", "type": "figure.martial.arts", "description": "A thrilling stunt show featuring death-defying feats and explosions.", "minHeight": null, "latitude": 28.3565, "longitude": -81.5585 },
      { "id": 5145, "parkId": 7, "name": "Muppet*Vision 3D", "type": "theatermasks.circle.fill", "description": "A chaotic and hilarious 3D movie experience starring the Muppets.", "minHeight": null, "latitude": 28.3570, "longitude": -81.5560 },
      { "id": 7333, "parkId": 7, "name": "For the First Time in Forever: A Frozen Sing-Along Celebration", "type": "music.mic", "description": "Sing along with favorite songs from the film 'Frozen' in this live musical production.", "minHeight": null, "latitude": 28.3580, "longitude": -81.5570 },
      { "id": 118, "parkId": 7, "name": "Disney Junior Play and Dance!", "type": "figure.and.child.holdinghands", "description": "A high-energy dance party featuring beloved Disney Junior characters.", "minHeight": null, "latitude": 28.3560, "longitude": -81.5570 },
      { "id": 110, "parkId": 8, "name": "Expedition Everest - Legend of the Forbidden Mountain", "type": "mountain.2.fill", "description": "Race through the Himalayas on a speeding train to escape the legendary Yeti.", "minHeight": 44, "latitude": 28.3582, "longitude": -81.5888 },
      { "id": 14533, "parkId": 8, "name": "Avatar Flight of Passage", "type": "leaf.fill", "description": "Fly on the back of a banshee on a breathtaking 3D ride over the world of Pandora.", "minHeight": 44, "latitude": 28.3550, "longitude": -81.5913 },
      { "id": 111, "parkId": 8, "name": "DINOSAUR", "type": "tortoise.fill", "description": "A thrilling and bumpy ride back in time to rescue a dinosaur before the meteor strikes.", "minHeight": 40, "latitude": 28.3558, "longitude": -81.5880 },
      { "id": 112, "parkId": 8, "name": "Kali River Rapids", "type": "drop.fill", "description": "Get soaked on a thrilling whitewater raft adventure through a lush jungle.", "minHeight": 38, "latitude": 28.3615, "longitude": -81.5891 },
      { "id": 651, "parkId": 8, "name": "Kilimanjaro Safaris", "type": "pawprint.fill", "description": "Climb aboard an open-air vehicle for a guided tour of a lush African savanna.", "minHeight": null, "latitude": 28.3627, "longitude": -81.5930 },
      { "id": 4438, "parkId": 8, "name": "Na'vi River Journey", "type": "music.mic", "description": "A gentle and mystical boat ride through a bioluminescent rainforest.", "minHeight": null, "latitude": 28.3548, "longitude": -81.5910 },
      { "id": 657, "parkId": 8, "name": "Festival of the Lion King", "type": "music.mic.circle.fill", "description": "A spectacular Broadway-style show filled with songs, pageantry, and puppetry from The Lion King.", "minHeight": null, "latitude": 28.3619, "longitude": -81.5932 },
      { "id": 10921, "parkId": 8, "name": "Finding Nemo: The Big Blue... and Beyond!", "type": "music.mic.circle.fill", "description": "Dive into the heart of the ocean with this musical stage show.", "minHeight": null, "latitude": 28.3570, "longitude": -81.5883 },
      { "id": 10920, "parkId": 8, "name": "It's Tough to be a Bug!", "type": "ant.fill", "description": "A humorous 3D film about the challenges of being a bug.", "minHeight": null, "latitude": 28.3598, "longitude": -81.5902 },
      { "id": 652, "parkId": 8, "name": "TriceraTop Spin", "type": "circle.grid.cross.fill", "description": "A gentle spinning ride where you can soar in your own TriceraTop.", "minHeight": null, "latitude": 28.3565, "longitude": -81.5875 },
      { "id": 13811, "parkId": 8, "name": "Gorilla Falls Exploration Trail", "type": "figure.walk.motion", "description": "Explore a lush walking trail featuring gorillas, hippos, and other African wildlife.", "minHeight": null, "latitude": 28.3610, "longitude": -81.5940 },
      { "id": 655, "parkId": 8, "name": "Wildlife Express Train", "type": "train.side.front.car", "description": "Take a rustic steam train to Rafiki's Planet Watch, an area dedicated to conservation.", "minHeight": null, "latitude": 28.3625, "longitude": -81.5960 },
      { "id": 13605, "parkId": 65, "name": "Hollywood Rip Ride Rockit", "type": "rollercoaster", "description": "A high-speed rock and roll coaster where you choose your own soundtrack.", "minHeight": 51, "latitude": 28.4754, "longitude": -81.4659 },
      { "id": 5984, "parkId": 65, "name": "Revenge of the Mummy", "type": "moon.stars.fill", "description": "Flee the evil mummy Imhotep on this high-speed indoor roller coaster.", "minHeight": 48, "latitude": 28.4776, "longitude": -81.4688 },
      { "id": 6000, "parkId": 65, "name": "Harry Potter and the Escape from Gringotts", "type": "wand.and.stars", "description": "Escape the bank of Gringotts on this multi-dimensional thrill ride.", "minHeight": 42, "latitude": 28.4779, "longitude": -81.4700 },
      { "id": 12107, "parkId": 65, "name": "TRANSFORMERS: The Ride-3D", "type": "bolt.car.fill", "description": "Battle against Decepticons in a thrilling 3D simulator ride.", "minHeight": 40, "latitude": 28.4752, "longitude": -81.4690 },
      { "id": 13110, "parkId": 65, "name": "The Simpsons Ride", "type": "tv.and.hifispeaker.fill", "description": "Crash, bump, and laugh your way through a 3D simulated adventure with The Simpsons.", "minHeight": 40, "latitude": 28.4770, "longitude": -81.4715 },
      { "id": 6018, "parkId": 65, "name": "Despicable Me Minion Mayhem", "type": "person.3.sequence.fill", "description": "Join Gru, his daughters, and the mischievous Minions on a heartwarming and hilarious 3D ride.", "minHeight": 40, "latitude": 28.4746, "longitude": -81.4680 },
      { "id": 5990, "parkId": 65, "name": "E.T. Adventure", "type": "bicycle", "description": "Fly your bicycle across the stars to help E.T. save his home planet.", "minHeight": 34, "latitude": 28.4772, "longitude": -81.4705 },
      { "id": 6038, "parkId": 65, "name": "Fast & Furious - Supercharged", "type": "car.2.fill", "description": "Join the Fast & Furious crew on a high-speed car chase.", "minHeight": 40, "latitude": 28.4760, "longitude": -81.4660 },
      { "id": 6014, "parkId": 65, "name": "Woody Woodpecker's Nuthouse Coaster", "type": "rollercoaster", "description": "Ride a fun, junior-sized roller coaster.", "minHeight": 36, "latitude": 28.4780, "longitude": -81.4710 },
      { "id": 6016, "parkId": 65, "name": "Hogwarts Express - King's Cross Station", "type": "train.side.front.car", "description": "Ride the famous train from London to Hogsmeade.", "minHeight": null, "latitude": 28.4782, "longitude": -81.4700 },
      { "id": 90101, "parkId": 65, "name": "The Bourne Stuntacular", "type": "theatermasks.fill", "description": "A thrilling live-action stunt show that follows Jason Bourne.", "minHeight": null, "latitude": 28.4765, "longitude": -81.4678 },
      { "id": 90102, "parkId": 65, "name": "Universal Orlando's Horror Make-Up Show", "type": "wand.and.stars.inverse", "description": "A hilarious, behind-the-scenes look at horror movie special effects.", "minHeight": null, "latitude": 28.4768, "longitude": -81.4670 },
      { "id": 5988, "parkId": 64, "name": "The Incredible Hulk Coaster", "type": "bolt.fill", "description": "Launch at incredible speeds and twist through inversions.", "minHeight": 54, "latitude": 28.4719, "longitude": -81.4717 },
      { "id": 13109, "parkId": 64, "name": "Hagrid's Magical Creatures Motorbike Adventure", "type": "wand.and.stars", "description": "Experience a thrilling motorbike coaster adventure through the Forbidden Forest.", "minHeight": 48, "latitude": 28.4709, "longitude": -81.4699 },
      { "id": 90001, "parkId": 64, "name": "Jurassic World VelociCoaster", "type": "rollercoaster", "description": "Hunt for raptors on this high-speed launch coaster.", "minHeight": 51, "latitude": 28.4740, "longitude": -81.4680 },
      { "id": 5987, "parkId": 64, "name": "Harry Potter and the Forbidden Journey", "type": "wand.and.stars", "description": "Soar above the Hogwarts castle grounds on a magical bench.", "minHeight": 48, "latitude": 28.4706, "longitude": -81.4696 },
      { "id": 5985, "parkId": 64, "name": "The Amazing Adventures of Spider-Man", "type": "camera.filters", "description": "Join Spider-Man in a thrilling 3D adventure battling villains.", "minHeight": 40, "latitude": 28.4729, "longitude": -81.4711 },
      { "id": 5997, "parkId": 64, "name": "Jurassic Park River Adventure", "type": "drop.fill", "description": "Enjoy a scenic water tour that culminates in an 85-foot plunge to escape a T-rex.", "minHeight": 42, "latitude": 28.4739, "longitude": -81.4682 },
      { "id": 5999, "parkId": 64, "name": "Doctor Doom's Fearfall", "type": "arrow.up.and.down.circle.fill", "description": "Experience a sudden and intense drop from the top of Doctor Doom's tower.", "minHeight": 52, "latitude": 28.4723, "longitude": -81.4714 },
      { "id": 8721, "parkId": 64, "name": "Flight of the Hippogriff", "type": "bird.fill", "description": "A family-friendly roller coaster that flies you around Hagrid's hut.", "minHeight": 36, "latitude": 28.4708, "longitude": -81.4692 },
      { "id": 5994, "parkId": 64, "name": "Dudley Do-Right's Ripsaw Falls", "type": "bubbles.and.sparkles.fill", "description": "Take a hilarious and soaking log flume journey.", "minHeight": 44, "latitude": 28.4735, "longitude": -81.4695 },
      { "id": 6011, "parkId": 64, "name": "Popeye & Bluto's Bilge-Rat Barges", "type": "lifepreserver.fill", "description": "Navigate treacherous rapids and splash down on this soaking river raft ride.", "minHeight": 42, "latitude": 28.4733, "longitude": -81.4690 },
      { "id": 6004, "parkId": 64, "name": "Pteranodon Flyers", "type": "airplane", "description": "Fly high above Jurassic Park on a suspended glider ride.", "minHeight": 36, "latitude": 28.4745, "longitude": -81.4686 },
      { "id": 6012, "parkId": 64, "name": "Caro-Seuss-el", "type": "circle.grid.cross.fill", "description": "Spin around on a colorful carousel featuring beloved Seuss characters.", "minHeight": null, "latitude": 28.4702, "longitude": -81.4678 },
      { "id": 6008, "parkId": 64, "name": "The Cat in the Hat", "type": "text.book.closed.fill", "description": "Journey through the classic Dr. Seuss story in this whimsical dark ride.", "minHeight": null, "latitude": 28.4698, "longitude": -81.4680 },
      { "id": 6017, "parkId": 64, "name": "The High in the Sky Seuss Trolley Train Ride!", "type": "tram.fill", "description": "Take a scenic journey high above Seuss Landing on a colorful trolley.", "minHeight": null, "latitude": 28.4700, "longitude": -81.4675 },
      { "id": 80001, "parkId": 64, "name": "Poseidon's Fury", "type": "water.waves.and.arrow.up", "description": "Journey through the ruins of the ancient temple of Poseidon in this special effects show.", "minHeight": null, "latitude": 28.4700, "longitude": -81.4688 },
      { "id": 100001, "parkId": 6, "name": "The Hall of Presidents", "type": "music.mic", "description": "Behold all Presidents of the United States in a stirring Audio-Animatronics show.", "minHeight": null, "latitude": 28.4179, "longitude": -81.5830 },
      { "id": 100002, "parkId": 5, "name": "Canada Far and Wide in Circle-Vision 360", "type": "film.stack.fill", "description": "A Circle-Vision 360 film showcasing the beauty and diversity of Canada.", "minHeight": null, "latitude": 28.3645, "longitude": -81.5490 },
      { "id": 100003, "parkId": 7, "name": "Beauty and the Beast Live on Stage", "type": "music.mic", "description": "Relive the tale as old as time in this Broadway-style stage production.", "minHeight": null, "latitude": 28.3550, "longitude": -81.5550 },
      { "id": 100004, "parkId": 8, "name": "Festival of the Lion King", "type": "music.mic.circle.fill", "description": "A spectacular Broadway-style show filled with songs, pageantry, and puppetry from The Lion King.", "minHeight": null, "latitude": 28.3619, "longitude": -81.5932 },
      { "id": 100005, "parkId": 64, "name": "Flight of the Hippogriff", "type": "bird.fill", "description": "A family-friendly roller coaster that flies you around Hagrid's hut.", "minHeight": 36, "latitude": 28.4708, "longitude": -81.4692 },
      { "id": 100006, "parkId": 65, "name": "Universal Orlando's Horror Make-Up Show", "type": "wand.and.stars.inverse", "description": "A hilarious, behind-the-scenes look at horror movie special effects.", "minHeight": null, "latitude": 28.4768, "longitude": -81.4670 },

      { "id": -33401, "parkId": 334, "name": "Universal's Epic Universe (Park Center)", "type": null, "description": "Main location for Epic Universe.", "minHeight": null, "latitude": 28.4549, "longitude": -81.4637 }
    ]
    """
    
    /// Average coordinates for each park ID, based on all attractions in that park.
    
    }


