# Security policy

## Threat model

macoswheels is a DriverKit System Extension that claims USB devices over the
interrupt and control transfer interfaces of Thrustmaster and Logitech racing
wheels. It is dev-signed and runs only on machines with SIP relaxed and
`systemextensionsctl developer on`. The relevant attack surfaces:

- A malicious USB device that VIDs/PIDs into our match table could send
  malformed input reports to the DEXT.
- A local process with `com.apple.developer.driverkit.userclient-access`
  for `it.allard.macoswheels` could send unexpected selector calls.

## Reporting

If you find a vulnerability, email **renaud@allard.it** with the details.
Please don't open a public issue for security-sensitive reports.

I'll acknowledge within a week and aim to land a fix within two; the small
scope of the project keeps the response loop short.

## Out of scope

- The dev-mode requirement itself: this project is fundamentally insecure
  by Apple's standard — it requires SIP relaxation. That's accepted by the
  user at install time and isn't something reports can address.
- macOS, DriverKit, or Apple-shipped sample-code vulnerabilities. Forward
  those to Apple via [Product Security](https://www.apple.com/support/security/).
- Vulnerabilities in upstream Linux kernel drivers (`hid-tmff2`, `new-lg4ff`,
  `t150_driver`) that we mirror protocol details from. Report those upstream.
