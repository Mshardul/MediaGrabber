#!/usr/bin/env swift
import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func read(_ path: String) -> Data {
    guard let data = FileManager.default.contents(atPath: path) else {
        fail("cannot read \(path)")
    }
    return data
}

func decode(_ text: String, _ what: String) -> Data {
    guard let data = Data(base64Encoded: text) else {
        fail("invalid base64 \(what)")
    }
    return data
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    fail("usage: ed25519.swift keygen | sign <private> <file> | verify <public> <signature> <file>")
}

switch command {
case "keygen":
    let key = Curve25519.Signing.PrivateKey()
    print("private=\(key.rawRepresentation.base64EncodedString())")
    print("public=\(key.publicKey.rawRepresentation.base64EncodedString())")
case "sign":
    guard arguments.count == 3 else { fail("usage: sign <privateB64> <file>") }
    do {
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: decode(arguments[1], "private key"))
        let signature = try key.signature(for: read(arguments[2]))
        print(signature.base64EncodedString())
    } catch {
        fail("cannot sign: \(error)")
    }
case "verify":
    guard arguments.count == 4 else { fail("usage: verify <publicB64> <signatureB64> <file>") }
    let key = (try? Curve25519.Signing.PublicKey(rawRepresentation: decode(arguments[1], "public key")))
    guard let key else { fail("invalid public key") }
    let signature = decode(arguments[2], "signature")
    exit(key.isValidSignature(signature, for: read(arguments[3])) ? 0 : 1)
default:
    fail("unknown command \(command)")
}
