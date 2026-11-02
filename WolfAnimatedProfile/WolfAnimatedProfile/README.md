# Wolf Animated Profile

Avatar + nen (cover) dong cho Facebook IPA (GIF / MP4). Chi hien thi tren may ban.

## Build
1. Cai Theos (https://theos.dev), dat $THEOS.
2. `make package`  ->  `.theos/obj/WolfAnimatedProfile.dylib`

## Inject vao IPA (khong can jailbreak)
Dung mot trong cac cong cu: Sideloadly (Advanced Options > Inject dylibs), cyan, azule:
    cyan -i Facebook__302_1__Wolf_v1_8.ipa -o Facebook_Anim.ipa -f .theos/obj/WolfAnimatedProfile.dylib
Sau do ky va cai bang Sideloadly / AltStore / TrollStore.
(IPA da co san libsubstrate.dylib nen cac tool se tu link vao.)

## Su dung
- Nhan giu 3 ngon tay ~1 giay tren man hinh -> menu.
- Chon "avatar dong" / "nen dong", chon GIF hoac video MP4 tu thu vien.
- Anh luu o Documents/WolfAnim/ cua app.

## Neu khong thay hieu ung (rat co the lan dau)
Tweak doan class bang ten (cover, profilepic, avatar...). Neu ban 303 dat ten khac:
1. Menu -> "Bat log debug", vao trang ca nhan, mo Documents/WolfAnim/debug.log.
2. Tim dong co kich thuoc dung (avatar ~ vuong, cover ~ rong) va xem chuoi class.
3. Them tu khoa vao mang trong WLAttach() (Tweak.xm).
Avatar chi ap dung cho view >= 100pt (tranh thay avatar ban be); chinh bang
`defaults` key wl_minsize hoac sua gia tri mac dinh trong WLMinSize().
