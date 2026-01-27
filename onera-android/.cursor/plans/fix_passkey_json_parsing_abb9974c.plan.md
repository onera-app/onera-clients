---
name: Fix Passkey JSON Parsing
overview: Fix the serialization error in PasskeyManager by using JsonObject for parsing WebAuthn responses instead of Map with Any type.
todos:
  - id: fix-parse-methods
    content: Update parseRegistrationResponse and parseAuthenticationResponse to use JsonObject instead of Map<String, Any>
    status: completed
---

# Fix Passkey JSON Parsing

## Problem

The `parseRegistrationResponse` and `parseAuthenticationResponse` methods in `PasskeyManager.kt` are using:

```kotlin
val responseMap = json.decodeFromString<Map<String, Any>>(responseJson)
```

Kotlinx.serialization cannot deserialize into `Any` type, causing the "Serializer for class 'Any' is not found" error.

## Solution

Change the parsing to use `JsonObject` (which we already import) and access values via JSON element accessors:

### File: [PasskeyManager.kt](app/src/main/java/chat/onera/mobile/data/security/PasskeyManager.kt)

Update both parsing methods to use `JsonObject` with `jsonPrimitive.content` for string extraction:

```kotlin
private fun parseRegistrationResponse(responseJson: String): WebAuthnRegistrationResponse {
    val responseObj = json.decodeFromString<JsonObject>(responseJson)
    
    val id = responseObj["id"]?.jsonPrimitive?.content ?: ""
    val rawId = responseObj["rawId"]?.jsonPrimitive?.content ?: id
    val type = responseObj["type"]?.jsonPrimitive?.content ?: "public-key"
    
    val response = responseObj["response"]?.jsonObject
    val clientDataJSON = response?.get("clientDataJSON")?.jsonPrimitive?.content ?: ""
    val attestationObject = response?.get("attestationObject")?.jsonPrimitive?.content ?: ""
    // ... rest of method
}

private fun parseAuthenticationResponse(responseJson: String): WebAuthnAuthenticationResponse {
    val responseObj = json.decodeFromString<JsonObject>(responseJson)
    
    val id = responseObj["id"]?.jsonPrimitive?.content ?: ""
    // ... similar pattern
}
```

This uses the same `JsonObject` type already used in `extractPRFOutputFromAuth` and `extractPRFOutputFromRegistration` methods.