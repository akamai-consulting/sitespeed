# **Welcome to the Advanced Services Sitespeed Portal**

The Sitespeed system requires the following components:

- Graphite
- Grafana
- Google
- Portal
- Sitespeed

The Graphite and Grafana components get installed on the same Linode.

The Google and Portal components each get installed on their own Linode.

The Sitespeed component is the primary testing machine, which gets installed on its own Linode. This componet should be installed in every location that you want to run tests.

To install each of the components use the following Stackscrips:

- sitespeed-graphite-grafana
- sitespeed-google
- sitespeed-jump
- sitespeed-sitespeed

The system requires name resolution of all Linodes.

To use the Google component you will need to obtain a GCP Chrome UX Report API key.
