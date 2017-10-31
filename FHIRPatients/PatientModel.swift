//
//  PatientModel.swift
//  FHIRDevDays
//
//  Created by Ryan Baldwin on 2017-10-08.
//  Copyright © 2017 bunnyhug.me. All rights reserved.
//

import Foundation
import UIKit
import FireKit
import RealmSwift
import Restivus

/// A model used for showing and /or editing the details of a Patient.
class PatientModel {
    /// The gender of the Patient, as defined by FHIR DSTU2's `AdministrativeGender`
    ///
    /// - male: The patient's gender is male
    /// - female: The patient's gender is female
    /// - other: The patient's gender is other
    /// - unknown: The patient's gender is unknown
    enum Gender: Int {
        case male, female, other, unknown
    }
    
    /// An optional call back to notify a listener if the
    /// patient contained in this model is in a saveable state.
    /// When `true`, the patient can be saved; otherwise false.
    var patientCanSaveChanged: ((Bool) -> ())? = nil
    
    /// An optional call back to notify a listener if the patient
    /// managed by this model has been updated.
    var managedPatientUpdated:(() -> ())? = nil
    
    /// The Realm used by this instance
    private var realm = try! Realm()
    
    /// The patient to edit. If this instance is creating a new Patient, then `patient` will be nil.
    private var patientToEdit: Patient? {
        didSet {
            if let patient = patientToEdit {
                setup(withPatient: patient)
            } else {
                gender = nil
                givenName = nil
                familyName = nil
                dateOfBirth = nil
                telecoms = []
            }
        }
    }
    
    /// Returns true if this patient can be downloaded from the remote FHIR server; otherwise false.
    var canDownloadPatient: Bool {
        return patientToEdit?.id != nil
    }
    
    /// Returns `true` if the patient can be uploaded to the remote FHIR server; otherwise `false`
    var canUploadPatient: Bool {
        guard let patient = self.patientToEdit else { return false }
        return realm.object(ofType: Patient.self, forPrimaryKey: patient.pk) != nil
    }
    
    /// Returns the `Reference` for the patient under edit.
    /// If this instance is being used to create a new patient,
    /// or edit a patient which has not been uploaded to the remote FHIR server,
    /// then `reference` returns nil.
    var reference: Reference? {
        guard let patientId = patientToEdit?.id else { return nil }
        return Reference(withReferenceId: "\(Patient.resourceType)/\(patientId)")
    }
    
    /// The image for this instance's patient's avatar
    var image: UIImage?

    /// The given name for this instance's patient
    var givenName: String? {
        didSet {
            patientCanSaveChanged?(canSave)
        }
    }
    
    /// The family name for this instance's patient
    var familyName: String? {
        didSet {
            patientCanSaveChanged?(canSave)
        }
    }
    
    /// The date of birth of this instance's patient
    var dateOfBirth: Date? {
        didSet {
            patientCanSaveChanged?(canSave)
        }
    }
    
    /// The gender (defined by FHIR's `AdministrativeGender`) of this isntance's patient
    var gender: Gender? {
        didSet {
            patientCanSaveChanged?(canSave)
        }
    }
    
    /// An array of FHIR `ContactPoint`s for this isntance's patient. Defaults to empty.
    var telecoms: [ContactPoint] = []
    
    /// Returns `true` if the patient can be saved; otherwise `false`.
    var canSave: Bool {
        return self.givenName?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0 > 0
            && self.familyName?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0 > 0
            && self.dateOfBirth != nil
            && self.gender != nil
    }
    
    /// Initializes this instance of the PatientModel
    ///
    /// - Parameter patient: When provided, this instance will operate in "edit mode" for the givne patient;
    ///                      otherwise this instance will create a new patient.
    init(patient: Patient? = nil) {
        guard let patient = patient else { return }
        self.patientToEdit = patient
        setup(withPatient: patient)
    }
    
    /// Setup this instance to operate over the provided `Patient`
    ///
    /// - Parameter patient: The `Patient` to edit for this instance.
    private func setup(withPatient patient: Patient) {
        givenName = patient.name.first?.given.first?.value
        familyName = patient.name.first?.family.first?.value
        dateOfBirth = patient.birthDate?.nsDate
        telecoms = patient.telecom.flatMap { $0.copy() as? ContactPoint }
        
        if let patientGender = patient.gender {
            switch patientGender {
            case "male": gender = .male
            case "female": gender = .female
            case "other": gender = .other
            default: gender = .unknown
            }
        }
        
        if let base64String = patient.photo.first?.data?.value,
            let image = UIImage(base64EncodedString: base64String) {
            self.image = image
        }
    }
    
    /// Permanently persists this patient to the local Realm.
    func save() {
        guard canSave else {
            print("Sorry, but you can't save yet. There are required fields.")
            return
        }
        
        // FHIRDevDays Lab TODO - 1:
        // 1.   Convert the in-memory model to a FireKit Patient persist that patient locally.
        //      Do not assign an `id` to the Patient object, as we will have the server assign one for us.
        //      In subsequent exercises we will use the existence of the `id` field to determine if the patient has
        //      been uploaded to or not.
        //      (hint: after a successul save, set `patientToEdit` to the patient created here)
        //
        // 2.   Update this `save` function to account the situation where this PatientModel was initialized
        //      with a Patient to Edit.
        //
        // Hints:
        //  - for the Photo: You can get a JPEG representation of the `userImage` using `UIImageJPEGRepresentation`
        //  - You can create a Base64Binary instance (`Attachment.data`) using `UIImageJPEGRepresentation.base64EncodedString(options:)`
        //  - Be careful when saving the `telecom` array! For this tutorial it's easier if you add copies of them
        //    to the `Patient.telecom` list instead of adding them directly. You can use a combination of `flatMap` and `copy()`
    }
    
    /// Uploads this patient to the server and
    ///
    /// - Parameter completion: called after a response is returned from the server, and an attempt was made
    ///                         Any errors that occured will be forwarded, or nil if everything worked as expected.
    ///
    /// Expected errors in the `completion` handler can be:
    ///   - [Restivus.HTTPError](https://ryanbaldwin.github.io/Restivus/docs/Enums/HTTPError.html):
    ///         Returned if the response received from the server is anything other than 2xx
    ///   - NSError: Returned if the attempt to save the patient locally fails.
    ///
    /// - Throws: `PatientOperationError` if:
    ///   - This instance is not managing a Patient
    ///   - The patient cannot be uploaded (possibly because it hasn't been saved yet)
    ///   - The attempt to submit the upload request failed
    func uploadPatient(completion: ((Error?) -> ())? = nil) throws {
        guard canUploadPatient, let patient = patientToEdit else {
            print("Cannot upload the patient at this time. Has the patient been saved?")
            throw PatientOperationError(message: "Cannot upload the patient at this time. Has the patient been saved?",
                                        error: nil)
        }
        
        // FHIRDevDays Lab TODO - 2:
        // 1.   In the `FHIRPatients/http/HttpPatient.swift`, create 2 Restivus requests for uploading a Patient:
        //      1 for POST'ing a new Patient to the server, and one for PUTing an existing patient to the server.
        //      Each request should conform to the `Encodable`, `Authenticating, and the respective Restable protocol:
        //      `Postable` for POST, and `Puttable` for PUT. Each request should have a `ResponseType` of `Patient`.
        //
        // 2.   Here, submit the appropriate request to add a new patient, or update the patient if it already exists
        //      on the server. We will use the presence of an `id` on the patient object to indicate if its been
        //      uploaded to the server or not. Upon a successful response, update the local patient to match the patient
        //      returned in the Restable response.
        //      (hint: using the `Patient.populate(from:)` function on a `Patient` instance makes this easy)
    }
    
    /// Downloads this patient from the server and updates it locally.
    ///
    /// - Parameter completion: called after a response is returned from the server, and an attempt was made to save.
    ///                         Any errors that occured will be forwarded as the argument in the `completion` block,
    ///                         or nil if everything worked as expected.
    ///
    /// Expected errors in the `completion` handler can be:
    ///   - [Restivus.HTTPError](https://ryanbaldwin.github.io/Restivus/docs/Enums/HTTPError.html):
    ///         Returned if the response received from the server is anything other than 2xx
    ///   - NSError: Returned if the attempt to save the patient locally fails.
    ///
    /// - Throws: `PatientOperationError` if:
    ///   - This instance is not managing a Patient
    ///   - The patient cannot be downloaded.
    ///   - The attempt to download the patient failed
    func downloadPatient(completion: ((Error?) -> ())? = nil) throws {
        guard canDownloadPatient, let patient = patientToEdit else {
            print("Cannot download the patient at this time. Does the patient have a proper `Reference`?")
            throw PatientOperationError(
                message: "Cannot download the patient at this time. Does the patient have a proper FHIR Reference?",
                error: nil)
        }
        
        // FHIRDevDays Lab TODO - 3:
        // 1.   In the `FHIRPatients/http/HttpPatient.swift` file, create a third `Restivus` request for downloading
        //      a specific patient (based on this instance's patient's `id`).
        //
        // 2.   Using the download request created in step `1.`, download the patient matching the `id` of this
        //      PatientModel's patient. Update the local patient with the one from the server.
        //
        // Hints:
        //  - Don't forget to set `self.patientToEdit` to the saved copy
        //  - using `upsert(_:)` makes saving this a breeze.
    }
}

/// An Error returned when an attempt to create a remote patient operation (such as upload or download a patient) fails.
struct PatientOperationError: Error {
    var message: String
    var error: Error?
}
