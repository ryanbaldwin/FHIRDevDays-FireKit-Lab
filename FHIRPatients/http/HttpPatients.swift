//
//  PatientRequest.swift
//  FHIRDevDays
//
//  Created by Ryan Baldwin on 2017-10-04.
//  Copyright © 2017 bunnyhug.me. All rights reserved.
//

import Foundation
import FireKit
import Restivus

/// A request which finds patients matching (fuzzily) a provided `family` name.
/// Provides a `FireKit.Bundle` of all matches returned by the server.
struct FindPatientsRequest: Authenticating, Gettable {
    typealias ResponseType = FireKit.Bundle
    var path: String { return "/Patient?family=\(familyName)" }
    
    /// The family name of the patients to find.
    var familyName: String
}

// FHIRDevDays Lab TODO:
//
// Throughout the lab you will eventually create 3 requests here:
//  - 1 for POSTing a Patient
//  - 1 for PUTing a Patient
//  - 1 for Downloading a specific patient (based on the patient's `id`)
//
//  The `FindPatientsRequest` above is used in the Search feature of the app, and searches for patients
//  on the server based on their family name. It has been left here for your reference.
//
//  Hints:
//      - The `HttpDefaults.swift` file has sensible defaults on how we want to communciate with the server.
//        Specifically, it has defaults for the `baseURL` (https://fhirtest.uhn.ca/baseDstu2) of all Restables, as
//        well it is using the `Authenticating` protocol to set the `Prefer` header to be `return=representation`
//      - Each request should expect a `Patient` type as the response from the server.
//      - You can get a specific resource from a FHIR server by using the path `/[Resource Type]/[id]`.
//        For example, you can see my patient record at https://fhirtest.uhn.ca/baseDstu2/Patient/83403
//      -
