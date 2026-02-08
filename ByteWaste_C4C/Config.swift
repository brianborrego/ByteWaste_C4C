//
//  Config.swift
//  ByteWaste_C4C
//
//  DO NOT commit this file to version control.
//

import Foundation

struct Config {
    // Edamam Food Database
    static let EDAMAM_BASE_URL = "https://api.edamam.com"
    static let EDAMAM_FOOD_PARSER_ENDPOINT = "/api/food-database/v2/parser"
    static let EDAMAM_AUTOCOMPLETE_ENDPOINT = "/auto-complete"
    static let FOOD_APP_ID = "8ed2ee10"
    static let FOOD_APP_KEY = "d5e2c45aef522057bdd8dd80092eb950"

    // Edamam Recipe API
    static let EDAMAM_NUTRIENTS_ENDPOINT = "/api/food-database/v2/nutrients"
    static let RECIPE_APP_ID = "8823c916"
    static let RECIPE_APP_KEY = "f77d18d885e70e39194dd3f09837d22a"

    // Navigator AI API
    static let navigatorAPIEndpoint = "https://api.ai.it.ufl.edu/v1"
    static let navigatorAPIKey = "sk-AUydy3z6VlN-xwA0cILqRw"
}
