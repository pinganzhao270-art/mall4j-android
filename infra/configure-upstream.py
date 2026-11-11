#!/usr/bin/env python3
"""Apply repeatable production-only settings to a pinned Mall4j checkout."""
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit

if len(sys.argv) != 5:
    raise SystemExit(
        "Usage: configure-upstream.py SOURCE_DIR RESOURCES_BASE_URL TOKEN_AES_KEY ADMIN_WEB_ORIGIN"
    )

source = Path(sys.argv[1]).resolve()
resources_url, token_key, admin_origin = sys.argv[2:]
resource = urlsplit(resources_url)
origin = urlsplit(admin_origin)

if (
    resource.scheme != "https"
    or not resource.netloc
    or resource.path != "/mall4j/img/"
    or resource.query
    or resource.fragment
):
    raise SystemExit("RESOURCES_BASE_URL must be HTTPS and end with /mall4j/img/")
if origin.scheme != "https" or not origin.netloc or origin.path or origin.query or origin.fragment:
    raise SystemExit("ADMIN_WEB_ORIGIN must be an HTTPS origin without a path")
if len(token_key.encode("utf-8")) not in (16, 24, 32) or not token_key.isalnum():
    raise SystemExit("TOKEN_AES_KEY must be exactly 16, 24 or 32 alphanumeric UTF-8 bytes")


def set_property(content: str, name: str, value: str) -> str:
    lines = content.splitlines()
    matches = [index for index, line in enumerate(lines) if line.startswith(name + "=")]
    if len(matches) != 1:
        raise SystemExit(f"Expected exactly one {name} property; found {len(matches)}")
    lines[matches[0]] = f"{name}={value}"
    return "\n".join(lines) + "\n"


properties = source / "yami-shop-common/src/main/resources/shop.properties"
cors = source / "yami-shop-security/yami-shop-security-common/src/main/java/com/yami/shop/security/common/config/CorsConfig.java"
upload_util = source / "yami-shop-common/src/main/java/com/yami/shop/common/util/ImgUploadUtil.java"
file_controller = source / "yami-shop-admin/src/main/java/com/yami/shop/admin/controller/FileController.java"

for path in (properties, cors, upload_util, file_controller):
    if not path.is_file():
        raise SystemExit(f"Expected Mall4j source file is missing: {path}")

property_text = properties.read_text(encoding="utf-8")
property_values = {
    "shop.tokenAesKey": token_key,
    "shop.imgUpload.imagePath": "/data/mall4j/images/",
    "shop.imgUpload.uploadType": "1",
    "shop.imgUpload.resourceUrl": resources_url,
}
for name, value in property_values.items():
    property_text = set_property(property_text, name, value)
properties.write_text(property_text, encoding="utf-8")

cors_lines = cors.read_text(encoding="utf-8").splitlines()
origin_indexes = []
for index, line in enumerate(cors_lines):
    stripped = line.strip()
    if stripped.startswith(("//", "/*", "*")):
        continue
    if 'configuration.addAllowedOriginPattern("*");' in stripped or re.fullmatch(
        r'configuration\.addAllowedOrigin\(".*"\);', stripped
    ):
        origin_indexes.append(index)
if len(origin_indexes) != 1:
    raise SystemExit(f"Expected one active CORS origin rule; found {len(origin_indexes)}")
index = origin_indexes[0]
indent = cors_lines[index][: len(cors_lines[index]) - len(cors_lines[index].lstrip())]
cors_lines[index] = indent + f'configuration.addAllowedOrigin("{admin_origin}");'
if any('addAllowedOriginPattern("*")' in line for line in cors_lines):
    raise SystemExit("Wildcard CORS origin remains enabled")
cors.write_text("\n".join(cors_lines) + "\n", encoding="utf-8")

upload_text = upload_util.read_text(encoding="utf-8")
old_upload = """        File file = new File(filePath + fileName);
        if (!file.exists()) {
            boolean result = file.mkdirs();
            if (!result) {
                throw new YamiShopBindException("创建目录：" + filePath + "失败");
            }
        }"""
new_upload = """        File file = new File(filePath + fileName);
        File parent = file.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs() && !parent.exists()) {
            throw new YamiShopBindException("创建目录：" + parent.getPath() + "失败");
        }"""
if old_upload in upload_text:
    upload_text = upload_text.replace(old_upload, new_upload)
elif new_upload not in upload_text:
    raise SystemExit("Unexpected image upload directory implementation; refusing to build")

old_delete = "        file.deleteOnExit();"
new_delete = """        if (file.exists() && !file.delete()) {
            throw new YamiShopBindException("删除文件失败：" + file.getPath());
        }"""
if old_delete in upload_text:
    upload_text = upload_text.replace(old_delete, new_delete)
elif new_delete not in upload_text:
    raise SystemExit("Unexpected image deletion implementation; refusing to build")
upload_util.write_text(upload_text, encoding="utf-8")

controller_text = file_controller.read_text(encoding="utf-8")
old_url = "data = imgUploadUtil.getUploadPath() + fileName;"
new_url = "data = imgUploadUtil.getResourceUrl() + fileName;"
if old_url in controller_text:
    controller_text = controller_text.replace(old_url, new_url)
elif new_url not in controller_text:
    raise SystemExit("Unexpected local rich-text image URL implementation; refusing to build")
file_controller.write_text(controller_text, encoding="utf-8")

print("Mall4j production properties, media handling and exact admin CORS origin configured.")
