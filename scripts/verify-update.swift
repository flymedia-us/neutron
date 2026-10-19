// Verify a Sparkle archive with its public Ed25519 key. Never accepts a private key.
import CryptoKit
import Foundation

let args = CommandLine.arguments
guard args.count == 4,
      let signature = Data(base64Encoded: args[2]),
      let key = Data(base64Encoded: args[3]) else {
    fatalError("Expected archive, base64 signature, and base64 public key")
}
let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: key)
let archive = try Data(contentsOf: URL(fileURLWithPath: args[1]), options: .mappedIfSafe)
guard publicKey.isValidSignature(signature, for: archive) else {
    fatalError("The update signature does not match the app's public key")
}
print("Update signature matches the app's public key.")
