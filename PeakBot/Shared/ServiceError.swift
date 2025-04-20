//
//  ServiceError.swift
//  PeakBot
//
//  Created by Bob Kitchen on 4/19/25.
//


import Foundation

/// Every error the Intervals.icu or local services can throw.
enum ServiceError: Error, LocalizedError {
    case invalidURL, unauthorized, notFound
    case serverError(status: Int)
    case csvParsing, decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "Bad API URL."
        case .unauthorized:            return "401 – check your API key."
        case .notFound:                return "404 – resource not found."
        case .serverError(let s):      return "Server replied (\(s))."
        case .csvParsing:              return "CSV couldn’t be parsed."
        case .decodingError(let err):  return err.localizedDescription
        }
    }
}