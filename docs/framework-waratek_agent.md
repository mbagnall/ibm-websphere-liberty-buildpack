# Waretek Agent Framework

# Current Set Up
The Waratek Agent Framework causes an application to be automatically configured to work with a specific version of [Waratek Agent Product][].
## Detection Criteria
An application indicates its intent to use the Waratek Agent by defining the following in its `manifest.yml`:

| Name | Value | Description
| ---- | ----- | -----------
| `buildpack:` | https://github.com/chippy65/waratek-ibm-websphere-liberty-buildpack#v2.0-alpha | Refer to the buildpack location on github
| `env: waratek_required:` | true | Application must set this environment variable to 'true' to engage Waratek
| `env: waratek_properties:` | Location of `waratek.properties` file relative to app dir | Optional parameter for applications to provide their own `waratek.properties` file. Location must be relative to app dir
| `env: waratek_treasure:` | Location of the Waratek Agent package | The Waratek Agent package would have been provided to the client (application owner) who in turn, makes this release available for use with the application
| `env: IBM_JVM_LICENSE:` | L-PMAA-A3Z8P2 | Mandatory use of IBM JVM license
| `env: IBM_LIBERTY_LICENSE:` | L-CTUR-AVDTCN | Mandatory use of IBM Liberty License   

Example Application `manifest/yml`:
```
---
applications:
 - name: GetStartedJava
   random-route: true
   path: target/GetStartedJava.war
   buildpack: https://github.com/chippy65/waratek-ibm-websphere-liberty-buildpack#v2.0-alpha
   memory: 256M
   instances: 1
   command: .liberty/create_vars.rb wlp/usr/servers/defaultServer/runtime-vars.xml && .liberty/calculate_memory.rb && 
WLP_SKIP_MAXPERMSIZE=true JAVA_HOME="$PWD/.java" WLP_USER_DIR="$PWD/wlp/usr" exec .liberty/bin/server run defaultServe
r
   env:
     waratek_required: true
     waratek_properties: ".waratek/waratek.properties"
     waratek_treasure: "https://bit.ly/abc123"
     IBM_JVM_LICENSE: L-PMAA-A3Z8P2
     IBM_LIBERTY_LICENSE: L-CTUR-AVDTCN
```

Tags are printed to standard output by the Buildpack detect script.

## Configuration
The framework can be configured by modifying the [`config/waratekagent.yml`][] file in the buildpack fork.  

| Name | Description
| ---- | -----------
| `uri` | The absolute URI of the Waratek Agent. Currently not implemented as yet - application provides URI
| `enabled` | Currently, set to `true` so the Waratek Agent assumes its always going to check if the app requests it
| `version` | The version of Waratek to use (not utilized but an entry is required).

```------------------------------------------------------------------------------------------------------------```
```------------------------------------------------------------------------------------------------------------```


# Future Set Up
The Waratek Agent Framework causes an application to be automatically configured to work with a bound [Waratek Service][].

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td>Existence of a single Waratek service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing at least one of the following:
      <ul>
        <li>name that has the substring <code>waratek</code>. <strong>Note: </strong> This is only applicable to user-provided services</li>
        <li>label that has the substring <code>waratek</code>.</li>
        <li>tags that have the substring <code>waratek</code>.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>waratek-&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the Buildpack detect script.

### User-Provided Service (Optional)
Users may optionally provide their own Waratek service. A user-provided Waratek service must have a name or tag with `waratek` in it so that the Waratek Agent Framework will automatically configure the application to work with the service.

The credential payload of the service may contain the following entries:

| Name | Description
| ---- | -----------
| `licenseKey` | The license key to use when authenticating

### Configuration
The framework can be configured by modifying the [`config/waratekagent.yml`][] file in the buildpack fork.  

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Waratek repository index.
| `version` | The version of Waratek to use. Candidate versions can be found in [this listing][].

#### Additional Resources
The framework can also be configured by overlaying a set of resources on the default distribution.  To do this, add files to the `resources/waratek_agent` directory in the buildpack fork.  For example, to override the default `waratek.yml` add your custom file to `resources/waratek_agent/waratek.yml`.

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/waratekagent.yml`]: ../config/waratekagent.yml
[Waratek Service]: https://www.waratek.com
[Waratek Agent Product]: https://www.waratek.com
[Waratek Buildpack]: https://github.com/chippy65/waratek-ibm-websphere-liberty-buildpack
[repositories]: extending-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/new-relic/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
