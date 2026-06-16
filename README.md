# Only Ads Roku Channel

This is a Roku-native SceneGraph channel that requests configured VAST ad tags, extracts playable ad media URLs, and plays them full-screen in a loop.

Roku does not run Flutter apps natively. Flutter supports Android, iOS, desktop, and web deployment targets, so the Roku implementation has to use BrightScript and SceneGraph.

## Configure

Edit `source/config.brs` and replace the sample URL with VAST ad tag URLs you are authorized to request.

```brightscript
return {
    vastTags: [
        "https://your-ad-server.example/vast.xml"
    ],
    requestTimeoutSeconds: 15,
    maxAdsPerRefresh: 10
}
```

Use only tags you own or have permission to call. Ad networks commonly require specific app, device, consent, privacy, and measurement parameters.

## Package

```sh
make package
```

The sideloadable zip is written to `build/only-ads.zip`.

## Sideload

Enable Developer Mode on your Roku, then run:

```sh
ROKU_DEV_TARGET=192.168.1.50 ROKU_DEV_PASSWORD='your-password' make install
```

## Remote Controls

- `OK` / `Play`: pause or resume
- `Right`: skip to the next loaded ad
- `Back`: exit the channel
