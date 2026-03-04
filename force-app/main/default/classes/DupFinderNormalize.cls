/**
 * Standard Duplicate Finder (Contacts & Leads)
 * Utility normalization helpers for heuristic matching.
 *
 * Copyright 2026 Jyotishko Roy (https://orcid.org/0009-0000-2837-4731)
 * Licensed under the Apache License, Version 2.0.
 */
public with sharing class DupFinderNormalize {

    // Conservative: avoid over-normalization that could create false positives.
    public static String normalizeEmail(String email) {
        if (String.isBlank(email)) return null;
        return email.trim().toLowerCase();
    }

    public static String digitsOnly(String input) {
        if (String.isBlank(input)) return null;
        String digits = input.replaceAll('[^0-9]', '');
        return String.isBlank(digits) ? null : digits;
    }

    /**
     * Phone matching uses the last N digits so that:
     *  - country codes don't prevent matching
     *  - formatting differences don't matter
     */
    public static String phoneKey(String phone, Integer lastNDigits) {
        if (lastNDigits == null || lastNDigits <= 0) lastNDigits = 7;
        String digits = digitsOnly(phone);
        if (digits == null) return null;
        if (digits.length() <= lastNDigits) return digits;
        return digits.substring(digits.length() - lastNDigits);
    }

    public static String normalizeName(String name) {
        if (String.isBlank(name)) return null;
        String n = name.trim().toLowerCase();
        // Remove punctuation-ish characters but keep letters/digits/spaces.
        n = n.replaceAll('[^a-z0-9 ]', ' ');
        // Collapse whitespace
        n = n.replaceAll('\s+', ' ').trim();
        return String.isBlank(n) ? null : n;
    }
}
