import "os" for Path

var Urls = {
  "aarch64": {
    "url": "https://www.nuget.org/api/v2/package/Microsoft.Windows.SDK.CPP.arm64/10.0.26100.1",
    "hash": "e0d6e5e019e28d92f24c9807afb04ad9e95ec685a1f742c30c3c7fe5abd0a109",
  },
  "x86_64": {
    "url": "https://www.nuget.org/api/v2/package/Microsoft.Windows.SDK.CPP.x64/10.0.26100.1",
    "hash": "7670843ddee568ca1e89b0feb36046ede6a3df5dbf5fa0106ec2eee9e8224e38",
  },
}

var windows = Fn.new { |b, args|
  if (b.target.os != "windows") Fiber.abort("windows sdk only available for windows")
  var platform = Urls[b.target.arch]
  var dir = b.untar(b.fetch(platform["url"], platform["hash"]), {"strip": 0})
  b.installDir("sdk", Path.join([dir, "c", "um", "x64"]))
}
