# Register and Execute binfmt
`binfmt` provides a way for a Linux kernel to execute binaries that are built for a different architecture. How it works is beyond the scope of this document.

This docker image provides both `qemu` binaries to interpret those executables and a registration to register them in your system.

To register, simply do:

```
docker run --rm --privileged deitch/binfmt_register
```

The above will do the following:

1. Determine if your kernel supports "fix binaries", where the interpreters included _in this image_ are registered to handle binaries.
2. Register the binaries in binfmt using "fix binaries" if it supports it, without otherwise.

## Interpreter Location
The Linux kernel supports two distinct modes of locating the interpreters:

* Execution-time
* Registration-time

You can control which mode is registered.

### Modes

#### Execution Time
In execution time mode, when the kernel looks for the interpreter registered to handle a file, e.g. `/usr/bin/qemu-aarch64-static`, it looks in the same container (specifically, mount namespace) as the _file being executed_. This requires that you have the interpreter available in that namespace. 

This is a signficant downside to this mode, and sometimes creates a chicken and egg problem. For that reason, the kernel, as of 4.8, also supports a different mode.

#### Registration Time
In registration time mode, indicated by a particular flag when registering an interpreters, the kernel looks for the interpreter at the moment of registration in the same container (specifically, mount namespace) as the _registration process_. When done this way, you no longer need to have the interpreter in the same containers as processes being run, just as the registration process at registration time.

### Defaults
By default, the registration process invoked by this container does the following:

1. If you explicitly specify to use execution time: execution time (no `F` flag)
2. If you explicitly specify to use registration time, and your kernel supports it: registration time (`F` flag)
3. If you explicitly specify to use registration time, and your kernel does not support it: error
4. If you do not specify, and your kernel supports registration time: registration time (`F` flag)
5. If you do not specify, and your kernel does not support registration time: execution time (no `F` flag)

## Overrides
By default, registration does *not* override existing registrations. If there already is binfmt configuration installed for a particular architecture, this registration will _not_ override it.

You can force it to do so by setting the environment variable `REPLACE=true`.

## Options
Registration supports the following options:

* `MODE`: Which interpreter mode to use, one of `registration`, `execution` or blank (default).
* `REPLACE`: Even if an interpreter is registered, replace it with one from here, one of "true" or blank (default).

All options are set as environment variables.

## Getting interpreters in execution time mode
If you run the registration process, and either chose to run inn execution time mode `MODE=execution` or your kernel does not support registration time, you **must** have the interpreter binaries available before the first time you attempt to run an alternate architecture binary.

The simplest way to do this is to copy the binaries over in a multistage `Dockerfile`. The following example creates an image that can run in `arm64`:

```dockerfile
FROM deitch/binfmt_register as qemu

FROM arm64v8/alpine:3.8
# Enable non-native builds of this image on an amd64 hosts.
# This must be the first RUN command in this file!
COPY --from=qemu /usr/bin/qemu-*-static /usr/bin/

RUN apk --update add curl
RUN curl -o /usr/local/bin/somebin https://from.com/some/file
ENTRYPOINT ["/usr/local/bin/somebin"]

```

In the above example, the final image will have the interpreters installed. Since you probably do _not_ want them there for the runtime image meant to be run on `arm64`, you can do the following:


```dockerfile
FROM deitch/binfmt_register as qemu

FROM arm64v8/alpine:3.8 as base
# Enable non-native builds of this image on an amd64 hosts.
# This must be the first RUN command in this file!
COPY --from=qemu /usr/bin/qemu-*-static /usr/bin/

RUN apk --update add curl
RUN curl -o /usr/local/bin/somebin https://from.com/some/file

FROM arm64v8/alpine:3.8
COPY --from=base /usr/local/bin/somebin /usr/local/bin/somebin
COPY --from=base /usr/bin/curl /usr/bin/curl
ENTRYPOINT ["/usr/local/bin/somebin"]
```

Your final image now has exactly what you need. This was performed in three steps:

1. Get the interpreters
2. Use the interpreters in an intermediate image to `curl` the binaries we needed
3. Create a final image that just copies over what we need from the intermediate.

Of course, the above example is contrived, as `/usr/bin/curl` has library dependencies which will not be met simply by copying over. Nonetheless, this shows the possibilities.

