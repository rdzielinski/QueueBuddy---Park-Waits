// Park+ThemeParksApiId.swift

import Foundation

extension Park {
    var parksApiId: String? {
        switch self.id {
        case 6:   return "WaltDisneyWorldMagicKingdom"
        case 5:   return "WaltDisneyWorldEpcot"
        case 7:   return "WaltDisneyWorldHollywoodStudios"
        case 8:   return "WaltDisneyWorldAnimalKingdom"
        case 64:  return "UniversalOrlandoIslandsOfAdventure"
        case 65:  return "UniversalOrlandoUniversalStudiosFlorida"
        case 334: return "UniversalEpicUniverse"
        default:  return nil
        }
    }
}
