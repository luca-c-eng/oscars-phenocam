# Project Provenance

This document records the software lineage and contributor attribution of the OSCARS-PHENOCAM development line.

It documents authorship and technical provenance. It does not determine or modify copyright ownership, licensing terms, or contractual rights.

## Project Lineage

| Item                    | Value                                           |
| ----------------------- | ----------------------------------------------- |
| Project                 | `oscars-phenocam`                               |
| Source repository       | `https://github.com/luca-c-eng/oscars-phenocam` |
| Source branch           | `dev/v1.8.0`                                    |
| Base commit             | `8bb006bb63eff2855aa15528d8828b4c92119045`      |
| Derived branch          | `dev/v0.1.0`                                    |
| Initial derived version | `0.1.0`                                         |

The `dev/v0.1.0` branch was created directly from the base commit identified above. The complete Git history, commit identifiers, authorship metadata, and timestamps preceding this development line have been preserved.

This is not an independent reimplementation or a source-code copy with a new history.

## Purpose of the Derived Line

Version `0.1.0` establishes a dedicated OSCARS development line derived from OSCARS-PHENOCAM v1.8.0.

Its purpose is to develop a sustainable OSCARS phenological camera system designed for interoperability with the ICOS Carbon Portal.

ICOS compatibility remains a development and validation objective until the required software implementation, staging integration, and system tests have been completed.

## Contributor Attribution

### Luca Cerato

**Affiliation:** Terrasystem S.R.L.

**Contribution roles:**

* Software architecture
* Software development
* Technical coordination
* Documentation
* System integration

Luca Cerato coordinated and developed the software forming the basis of this development line and continues its technical development for the OSCARS project and interoperability with ICOS.

The Git commit history remains the authoritative technical record of individual changes and their recorded authorship.

## External Software

### phenocam-vision-edge

**Developer:** Emanuele Tufarini  
**Affiliation:** Terrasystem S.R.L.

OSCARS-PHENOCAM integrates the separately maintained `phenocam-vision-edge` software:

* Project: `phenocam-vision-edge`
* Repository: `https://github.com/e-tufarini-terrasystem/phenocam-vision-edge`
* Integrated release at the derivation point: `v0.2.3`

The external project's own repository history, authorship records, and licence govern its attribution and use.

## History Preservation

Any repository migration or organizational transfer should preserve:

* the complete Git commit history;
* original commit hashes;
* author and committer metadata;
* commit timestamps;
* branches and release tags;
* this provenance document;
* the reference to the v1.8.0 base commit.

History rewriting, squashing the existing development history, or importing only the current files would weaken the verifiable provenance of the project and should be avoided.

## Verification

The derivation point can be verified with:

```bash
git rev-parse dev/v1.8.0
git rev-parse dev/v0.1.0
```

At the creation of the derived branch, both commands resolved to:

```text
8bb006bb63eff2855aa15528d8828b4c92119045
```

The preserved history can be inspected with:

```bash
git log --format=fuller
```

## Copyright and Licence

This document records contributions and software lineage only.

The licence distributed with the repository continues to apply. Copyright ownership and any contractual rights must be verified separately with the relevant parties before changing the copyright notice or licensing terms.
