# sunst0rmd

`WARNING: USE AT YOUR OWN RISK! WHATEVER HAPPENS TO YOUR DEVICE IS YOUR RESPONSIBILITY.`

This is a rewrite of sunst0rm in bash.

Only macOS supported!

This is only tested on iPhone 7 (d101ap)

[SEP/BB Compatibility Chart](https://docs.google.com/spreadsheets/d/1Mb1UNm6g3yvdQD67M413GYSaJ4uoNhLgpkc7YKi3LBs/)

Requirements:
  - Installed Xcode
  - Installed Xcode Command Line Tools `$ xcode-select --install`
  - Installed [Homebrew](https://brew.sh)
  - Downloaded IPSW (target iOS firmware) which can be found at [ipsw.me](https://ipsw.me)
  - Installed without brew: `futurerestore` `libirecovery` `Python 3`
  <!-- - Installed manually: [libimg4tool](https://github.com/m1stadev/img4tool) -->

Usage:
  - Run: `./sunst0rm.sh restore <ipsw path>` to restore
  - Then run: `./sunst0rm.sh boot` to boot

## Credits / Thanks

[futurerestore contributors](https://github.com/futurerestore)

[xerub](https://github.com/xerub) - img4lib

[tihmstar](https://github.com/tihmstar) - img4tool, tsschecker

[libimobiledevice](https://github.com/libimobiledevice) - libirecovery

[0x7ff](https://github.com/0x7ff) - gaster

[Cryptiiiic](https://github.com/Cryptiiiic) - iBoot64Patcher's fork

[iSuns9](https://github.com/iSuns9) - restored_external64_patcher, Kernel64Patcher's fork

[exploit3dguy](https://github.com/exploit3dguy) - asr64_patcher

[ProcursusTeam](https://github.com/ProcursusTeam) - ldid's fork

[m1stadev](https://github.com/m1stadev) - pyimg4

[sen0rxol0](https://github.com/sen0rxol0) - all their contributions / pull requests

[mineek](https://github.com/mineek) - ios tethered downgrade guide
