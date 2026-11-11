#!/usr/bin/env python3
"""Apply production-only Mall4j settings to a separate upstream checkout."""
from pathlib import Path
import sys
from urllib.parse import urlsplit

if len(sys.argv) != 5:
    raise SystemExit("Usage: configure-upstream.py SOURCE_DIR RESOURCES_BASE_URL TOKEN_AES_KEY ADMIN_WEB_ORIGIN")

source = Path(sys.argv[1]).resolve()
resources_url, token_key, admin_origin = sys.argv[2:]
resource = urlsplit(resources_url)
origin = urlsplit(admin_origin)
if resource.scheme != "https" or not resource.netloc or resource.path != "/mall4j/img/" or resource.query or resource.fragment:
    raise SystemExit("RESOURCES_BASE_URL must be HTTPS and end with /mall4j/img/")
if origin.scheme != "https" or not origin.netloc or origin.path or origin.query or origin.fragment:
    raise SystemExit("ADMIN_WEB_ORIGIN must be an HTTPS origin without a path")
if len(token_key.encode("utf-8")) not in (16, 24, 32) or not token_key.isalnum():
    raise SystemExit("TOKEN_AES_KEY must be exactly 16, 24 or 32 UTF-8 bytes")

properties = source / "yami-shop-common/src/main/resources/shop.properties"
cors = source / "yami-shop-security/yami-shop-security-common/src/main/java/com/yami/shop/security/common/config/CorsConfig.java"
if not properties.is_file() or not cors.is_file():
    raise SystemExit("The supplied source directory is not the expected Mall4j checkout")

text = properties.read_text(encoding="utf-8")
replacements = {
    "shop.tokenAesKey=q5e6w6w9f4q497te": f"shop.tokenAesKey={token_key}",
    "shop.imgUpload.imagePath=D:/Mall4j/IMG/": "shop.imgUpload.imagePath=/data/mall4j/images/",
    "shop.imgUpload.uploadType=2": "shop.imgUpload.uploadType=1",
    "shop.imgUpload.resourceUrl=http://localhost:8085/mall4j/img/": f"shop.imgUpload.resourceUrl={resources_url}",
}
for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new)
    elif new not in text:
        raise SystemExit(f"Expected Mall4j property not found: {old}")
properties.write_text(text, encoding="utf-8")

cors_text = cors.read_text(encoding="utf-8")
wildcard = 'configuration.addAllowedOriginPattern("*");'
specific = f'configuration.addAllowedOrigin("{admin_origin}");'
if wildcard in cors_text:
    cors_text = cors_text.replace(wildcard, specific)
elif specific not in cors_text:
    raise SystemExit("Unexpected upstream CORS configuration; refusing unsafe build")
if 'addAllowedOriginPattern("*")' in cors_text:
    raise SystemExit("Wildcard CORS origin remains enabled")
cors.write_text(cors_text, encoding="utf-8")

upload_util = source / "yami-shop-common/src/main/java/com/yami/shop/common/util/ImgUploadUtil.java"
if not upload_util.is_file():
    raise SystemExit("Mall4j image upload utility is missing")
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

old_delete = """        file.deleteOnExit();"""
new_delete = """        if (file.exists() && !file.delete()) {
            throw new YamiShopBindException("删除文件失败：" + file.getPath());
        }"""
if old_delete in upload_text:
    upload_text = upload_text.replace(old_delete, new_delete)
elif new_delete not in upload_text:
    raise SystemExit("Unexpected image deletion implementation; refusing to build")
upload_util.write_text(upload_text, encoding="utf-8")

print("Mall4j production properties, image uploads and exact admin CORS origin configured.")
