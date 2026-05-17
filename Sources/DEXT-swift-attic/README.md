# Swift DEXT attic

The Swift implementation of the DEXT lived here until 2026-05-17. It was moved
out because Apple has not shipped a Swift standard library for DriverKit in
any installed Xcode (verified Xcode 16.0, 16.4, 26.3 — see
`docs/DEV-MODE-SETUP.md` §4 for the receipts).

The active DEXT now uses IIG / C++23 in `Sources/DEXT/`.

These Swift files are preserved as design reference — the class shapes,
selector tables, and lifecycle logic translate fairly directly. When (if)
Apple ships a Swift DriverKit stdlib, this attic is the starting point for a
Swift port.
