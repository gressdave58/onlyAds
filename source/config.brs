function GetAdConfig() as object
    ' Replace this with a full VAST URL you are authorized to request.
    ' Google Ad Manager tags usually look like:
    ' https://securepubads.g.doubleclick.net/gampad/ads?env=vp&gdfp_req=1&output=vast&iu=/NETWORK/AD_UNIT&sz=1920x1080&correlator=12345
    return {
        vastTags: [
            "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/single_ad_samples&sz=640x480&cust_params=sample_ct%3Dlinear&ciu_szs=300x250%2C728x90&gdfp_req=1&output=vast&unviewed_position_start=1&env=vp&correlator={correlator}"
        ],
        requestTimeoutSeconds: 15,
        maxAdsPerRefresh: 10,
        debugEnabled: true
    }
end function
