import Foundation
import CryptoKit
import Security

/// Cifrado de los cuerpos de snippets sensibles: AES-GCM 256 con CryptoKit.
///
/// La llave vive en el Keychain; el texto cifrado vive en el JSON de la app.
/// Esa separación es el punto entero: una llave guardada junto al texto cifrado
/// no es cifrado, es ofuscación.
///
/// **Qué protege:** que alguien lea el archivo — un backup de Time Machine, una
/// carpeta sincronizada, otro usuario del Mac.
/// **Qué no protege:** malware corriendo como el usuario, que puede pedirle la
/// llave al Keychain igual que la app.
///
/// Nota operativa: los ítems del Keychain se atan a la firma de código. Con firma
/// ad-hoc el hash del binario cambia en cada build, así que macOS pedirá permiso
/// otra vez tras cada `build.sh` — el mismo peaje que Accesibilidad, por la misma
/// causa. Un Developer ID lo elimina.
struct SecretBox {

    enum SecretBoxError: LocalizedError {
        case keyUnavailable(OSStatus)
        case sealFailed
        case openFailed

        var errorDescription: String? {
            switch self {
            case .keyUnavailable(let status):
                return "No se pudo acceder a la llave de cifrado en el Keychain (código \(status)). "
                     + "Tras recompilar la app, macOS pide permiso otra vez porque la firma cambió."
            case .sealFailed:
                return "No se pudo cifrar el contenido."
            case .openFailed:
                return "No se pudo descifrar el contenido. El archivo puede estar dañado, "
                     + "o cifrado con una llave que ya no está en este Mac."
            }
        }
    }

    static let keychainService = "com.user.WhisperBar"
    static let keychainAccount = "snippets-encryption-key-v1"

    private let key: SymmetricKey

    /// Inyectable para tests: no tocan el Keychain real ni disparan diálogos.
    init(key: SymmetricKey) {
        self.key = key
    }

    /// Carga la llave del Keychain, o la crea la primera vez.
    static func keychainBacked() throws -> SecretBox {
        if let existing = try loadKey() { return SecretBox(key: existing) }
        let fresh = SymmetricKey(size: .bits256)
        try storeKey(fresh)
        return SecretBox(key: fresh)
    }

    // MARK: - Cifrado

    func seal(_ plaintext: String) throws -> Data {
        guard let sealed = try? AES.GCM.seal(Data(plaintext.utf8), using: key),
              let combined = sealed.combined else {
            throw SecretBoxError.sealFailed
        }
        return combined
    }

    func open(_ ciphertext: Data) throws -> String {
        guard let box = try? AES.GCM.SealedBox(combined: ciphertext),
              let opened = try? AES.GCM.open(box, using: key),
              let text = String(data: opened, encoding: .utf8) else {
            throw SecretBoxError.openFailed
        }
        return text
    }

    // MARK: - Keychain

    private static func loadKey() throws -> SymmetricKey? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw SecretBoxError.keyUnavailable(status)
        }
    }

    private static func storeKey(_ key: SymmetricKey) throws {
        var attributes = baseQuery()
        attributes[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        // ThisDeviceOnly: la llave no viaja en backups ni al llavero de iCloud.
        // Si el usuario restaura en otro Mac, los sensibles quedan ilegibles ahí,
        // que es lo correcto para un secreto local.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw SecretBoxError.keyUnavailable(status)
        }
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
    }
}
