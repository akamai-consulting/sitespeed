# **Advanced Solutions Sitespeed Portal**

The Sitespeed system requires the following components:

- Graphite
- Grafana
- Google
- Portal
- Sitespeed

The Graphite and Grafana components get installed on the same Linode.

The Google and Portal components get installed on their own Linodes.

The Sitespeed component is the primary testing machine, which gets installed on its own Linode. This component should be installed in every location that you want to run tests.

To install each of the components use the following Stackscripts:

- sitespeed-graphite-grafana
- sitespeed-google
- sitespeed-jump
- sitespeed-sitespeed

The system requires name resolution of all Linodes.

To use the Google component you will need to obtain a GCP Chrome UX Report API and PageSpeed Insights APIs.

Use the Planner Guide (Info/Planner.pdf) to predefine all of the required information, which will make the installation process go faster.
