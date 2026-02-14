# Stw Paystation

تم إنشاء هذا السكربت بالكامل من الصفر بواسطة **Stw Store**.

### Stw Store
- جميع الحقوق محفوظة لـ **Stw Store**.
- السكربت مصمم خصيصاً ليقدم تجربة فريدة وسلسة.

### الدعم الفني والتواصل
يمكنكم الانضمام إلى سيرفر الديسكورد الخاص بنا للحصول على الدعم أو لرؤية المزيد من أعمالنا:
- **Discord**: `https://discord.gg/Dz2AuVB47Q`

---
*Created with ❤️ by Stw Store*

## المتطلبات
- interact: `https://github.com/darktrovx/interact`
- ox_lib: `https://github.com/overextended/ox_lib`


## تركيب الأيتم rentalpapers
- ( qb-core/shared/items.lua).

```lua
["rentalpapers"] = { ["name"] = "rentalpapers", ["label"] = "Rental Papers", ["weight"] = 0, ["type"] = "item", ["image"] = "rentalpapers.png", ["unique"] = true, ["useable"] = false, ["shouldClose"] = false, ["combinable"] = nil, ["description"] = "Vehicle rental proof" },
```

## (JS)

 
- تحط ذا داخل ( FormatItemInfo في ملف الapp.js الي عندك في الحقيبة )

```js
else if (item.name === "rentalpapers") {
  const info = item.info || {};
  const vehicle = (info.vehicle || "Unknown");
  const renter  = (info.renter  || "Unknown");
  const plateLine = info.plate ? `PLATE: ${info.plate}<br>` : "";
  stats = `VEHICLE: ${vehicle}<br>RENTER: ${renter}<br>${plateLine}`;
}
```
## صور
![Screenshot 1](https://cdn.discordapp.com/attachments/1254759277717880844/1472164464852861031/image.png?ex=6991937f&is=699041ff&hm=63533a53ce1ab7f25f2ac2feda4b4abf9cc69523a70402f26e408ad87c0c3c86&)
![Screenshot 2](https://cdn.discordapp.com/attachments/1254759277717880844/1472164465347661976/image.png?ex=69919380&is=69904200&hm=be7b2781b237e989f5ee33aa7de1b53f274568e409e6f5a64b36e8063674cf87&)
![Screenshot 3](https://cdn.discordapp.com/attachments/1254759277717880844/1472164465968545947/image.png?ex=69919380&is=69904200&hm=9c8bdb725bf3f1df20a0b87d5167dc3ed2f6ad9d513577b306e885064cc1194f&)

