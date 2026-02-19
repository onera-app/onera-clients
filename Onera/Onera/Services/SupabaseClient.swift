//
//  SupabaseClient.swift
//  Onera
//
//  Supabase client singleton for authentication
//

import Foundation
import Supabase

/// Shared Supabase client instance.
/// The SDK automatically persists sessions to Keychain and refreshes tokens.
let supabase = SupabaseClient(
    supabaseURL: Configuration.supabaseURL,
    supabaseKey: Configuration.supabaseAnonKey
)
