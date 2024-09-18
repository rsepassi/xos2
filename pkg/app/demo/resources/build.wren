var resources = Fn.new { |b, args|
  b.install("", [
    b.src("CourierPrime-Regular.ttf"),
    b.src("EBGaramond-Regular.ttf"),
    b.src("coast.jpg"),
    b.src("fleur.png"),
    b.src("communist-manifesto.epub"),
  ])
}
