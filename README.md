# shai-hulud-2.0-detector

This tool helps detect npm packages impacted by the Shai-Hulud 2.0 supply chain attack by checking installed package versions against a known list of compromised versions.

## Background

The Shai-Hulud 2.0 supply chain attack is an ongoing malicious campaign that has exposed vulnerabilities in thousands of npm packages, impacting many projects by injecting malicious code through compromised package versions.

## How it works

The detection is performed by a Bash script `checker.sh` which analyzes the npm packages installed in a given project. It compares the installed package versions against a supplied CSV file (`shai-hulud-2-packages.csv`) that lists packages and versions impacted by the attack.

## Usage

```bash
./checker.sh /path/to/your/project
```

- The script takes one argument: the path to the npm project whose installed packages you want to check.
- It requires access to the `shai-hulud-2-packages.csv` file, which contains the compromised package versions ([source](https://github.com/wiz-sec-public/wiz-research-iocs/blob/main/reports/shai-hulud-2-packages.csv)).
- The script outputs a summary including:
  - Total installed packages analyzed
  - Packages with confirmed issues (versions known to be compromised)
  - Packages with potential issues (installed version close to impacted versions)

### Recursively check all immediate npm projects under a base directory

You can now use the `-r` option to recursively check all npm projects under a base directory. Note that this only checks the immediate subdirectories (depth 0) of the given path.

```bash
./checker.sh -r /path/to/base-directory
```

- This will scan each immediate subdirectory for a `package.json` file and run the check on those npm projects.
- This option helps to quickly audit many related projects in one go while avoiding deep recursive scanning.

## CSV File

The `shai-hulud-2-packages.csv` contains a list of npm packages and compromised versions in the following format:

```
Package,Version
package-name,= x.y.z || = a.b.c
another-package,= x.y.z
...
```

[source](https://github.com/wiz-sec-public/wiz-research-iocs/blob/main/reports/shai-hulud-2-packages.csv)

## Related Articles

- [Shai-Hulud 2.0 Supply Chain Attack: 25K+ Repos Exposing Secrets](https://www.wiz.io/blog/shai-hulud-2-0-ongoing-supply-chain-attack)
- [GitLab discovers widespread npm supply chain attack](https://about.gitlab.com/blog/gitlab-discovers-widespread-npm-supply-chain-attack/)

## Disclaimer

This tool helps identify known compromised package versions but does not guarantee full protection. Always keep dependencies updated and verify package integrity with best practices.
