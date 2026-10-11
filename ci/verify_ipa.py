"""Inspect an unsigned device IPA on Windows or macOS; stdlib only."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import stat
import struct
import zipfile


def macho_images(data):
    magic = data[:4]
    if magic in (b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'):
        count = struct.unpack_from('>I', data, 4)[0]
        wide = magic == b'\xca\xfe\xba\xbf'
        for index in range(count):
            base = 8 + index * (32 if wide else 20)
            offset, size = struct.unpack_from('>QQ' if wide else '>II', data, base + 8)
            yield from macho_images(data[offset:offset + size])
        return
    if magic not in (b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe',
                     b'\xfe\xed\xfa\xcf', b'\xfe\xed\xfa\xce'):
        return
    endian = '<' if magic[0] in (0xcf, 0xce) else '>'
    cpu, _, _, commands = struct.unpack_from(endian + 'IIII', data, 4)
    offset = 32 if magic in (b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf') else 28
    platforms = []
    signature = False
    for _ in range(commands):
        command, size = struct.unpack_from(endian + 'II', data, offset)
        if size < 8 or offset + size > len(data):
            raise ValueError('Invalid Mach-O load command')
        if command == 0x32:
            platforms.append(struct.unpack_from(endian + 'I', data, offset + 8)[0])
        elif command == 0x25:
            platforms.append(2)
        elif command == 0x1d:
            signature |= struct.unpack_from(endian + 'I', data, offset + 12)[0] > 0
        offset += size
    yield {'cpu_type': cpu, 'platforms': platforms, 'has_signature': signature}


def verify(path):
    with zipfile.ZipFile(path) as archive:
        if archive.testzip():
            raise ValueError('ZIP CRC check failed')
        names = archive.namelist()
        for name in names:
            parts = PurePosixPath(name)
            if parts.is_absolute() or '..' in parts.parts:
                raise ValueError('Unsafe ZIP path')
            if (parts.suffix.lower() in {'.p12', '.pfx', '.mobileprovision',
                                         '.mobileconfig', '.pem', '.key'}
                    or 'password' in parts.name.lower()
                    or '_CodeSignature' in parts.parts):
                raise ValueError('Signing material or signature resource found')
        infos = [n for n in names if n.startswith('Payload/')
                 and n.endswith('.app/Info.plist') and n.count('/') == 2]
        if len(infos) != 1:
            raise ValueError('Expected exactly one Payload/*.app/Info.plist')
        info = plistlib.loads(archive.read(infos[0]))
        if info.get('CFBundlePackageType') != 'APPL':
            raise ValueError('Bundle is not an iOS application')
        executable = infos[0].rsplit('/', 1)[0] + '/' + info['CFBundleExecutable']
        main_images = list(macho_images(archive.read(executable)))
        if not any(i['cpu_type'] == 0x0100000c and 2 in i['platforms']
                   for i in main_images):
            raise ValueError('Main executable is not an arm64 iOS device binary')
        if not archive.getinfo(executable).external_attr >> 16 & stat.S_IXUSR:
            raise ValueError('Executable permission missing')
        binaries = []
        for entry in archive.infolist():
            if entry.is_dir():
                continue
            with archive.open(entry) as stream:
                magic = stream.read(4)
            if magic in (b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf',
                         b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe',
                         b'\xfe\xed\xfa\xcf', b'\xfe\xed\xfa\xce'):
                images = list(macho_images(archive.read(entry)))
                if any(i['has_signature'] for i in images):
                    raise ValueError('Mach-O code signature remains: ' + entry.filename)
                if any(7 in i['platforms'] for i in images):
                    raise ValueError('Simulator binary found: ' + entry.filename)
                binaries.append({'path': entry.filename, 'images': images})
    return {
        'file': path.name,
        'bytes': path.stat().st_size,
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'bundle_id': info['CFBundleIdentifier'],
        'version': info['CFBundleShortVersionString'],
        'build_number': info['CFBundleVersion'],
        'minimum_ios': info.get('MinimumOSVersion'),
        'unsigned': True,
        'device_arm64': True,
        'zip_crc_ok': True,
        'binaries': binaries,
        'installation_verified': False,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('ipa', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    result = verify(args.ipa)
    output = json.dumps(result, ensure_ascii=False, indent=2)
    if args.report:
        args.report.write_text(output + '\n', encoding='utf-8')
    print(output)
