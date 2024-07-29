import 'tags_info.dart' show MakerTag, TagsBase;
import 'package:sprintf/sprintf.dart' show sprintf;

// Makernote (proprietary) tag definitions for Canon.
// http://www.sno.phy.queensu.ca/~phil/exiftool/TagNames/Canon.html

class MakerNoteCanon extends TagsBase {
  static MakerTag _make(String name) => MakerTag.make(name);

  static MakerTag _withMap(String name, Map<int, String> map) =>
      MakerTag.makeWithMap(name, map);

  static final tags = {
    0x0002: _make('FocalLength'),
    0x0003: _make('FlashInfo'),
    0x0005: _make('PanoramaInfo'),
    0x0006: _make('ImageType'),
    0x0007: _make('FirmwareVersion'),
    0x0008: _make('ImageNumber'),
    0x0009: _make('OwnerName'),
    0x000c: _make('SerialNumber'),
    0x000e: _make('FileLength'),
    0x0010: _make('ModelID'),
    0x0013: _make('ThumbnailImageValidArea'),
    0x0015: _withMap(
      'SerialNumberFormat',
      {0x90000000: 'Format 1', 0xA0000000: 'Format 2'},
    ),
    0x001a:
        _withMap('SuperMacro', {0: 'Off', 1: 'On const ()', 2: 'On const ()'}),
    0x001c: _withMap('DateStampMode', {
      0: 'Off',
      1: 'Date',
      2: 'Date & Time',
    }),
    0x001e: _make('FirmwareRevision'),
    0x0028: _make('ImageUniqueID'),
    0x0095: _make('LensModel'),
    0x0096: _make('InternalSerialNumber'),
    0x0097: _make('DustRemovalData '),
    0x0098: _make('CropInfo'),
    0x009a: _make('AspectInfo'),
    0x00b4: _withMap('ColorSpace', {1: 'sRGB', 2: 'Adobe RGB'}),
    0x00e0: _make('SensorInfo'),
    0x4003: _make('ColorInfo'),
    0x4019: _make('LensInfo'),
    0x4024: _make('FilterInfo'),
    0x4025: _make('HDRInfo'),
  };

  static final tagsXxx = {
    'MakerNote Tag 0x0001': cameraSettings,
    'MakerNote Tag 0x0004': shotInfo,
    'MakerNote Tag 0x0026': afInfo2,
    'MakerNote Tag 0x0093': fileInfo,
  };

  // this is in element offset, name, optional value dictionary format
  // 0x0001
  static Map<int, MakerTag> cameraSettings = {
    1: _withMap('Macromode', {1: 'Macro', 2: 'Normal'}),
    2: _make('SelfTimer'),
    3: _withMap(
      'Quality',
      {1: 'Economy', 2: 'Normal', 3: 'Fine', 5: 'Superfine'},
    ),
    4: _withMap(
      'FlashMode',
      {
        0: 'Flash Not Fired',
        1: 'Auto',
        2: 'On',
        3: 'Red-Eye Reduction',
        4: 'Slow Synchro',
        5: 'Auto + Red-Eye Reduction',
        6: 'On + Red-Eye Reduction',
        16: 'external flash',
      },
    ),
    5: _withMap('ContinuousDriveMode', {
      0: 'Single Or Timer',
      1: 'Continuous',
      2: 'Movie',
    }),
    7: _withMap(
      'FocusMode',
      {
        0: 'One-Shot',
        1: 'AI Servo',
        2: 'AI Focus',
        3: 'MF',
        4: 'Single',
        5: 'Continuous',
        6: 'MF',
      },
    ),
    9: _withMap('RecordMode', {
      1: 'JPEG',
      2: 'CRW+THM',
      3: 'AVI+THM',
      4: 'TIF',
      5: 'TIF+JPEG',
      6: 'CR2',
      7: 'CR2+JPEG',
      9: 'Video',
    }),
    10: _withMap('ImageSize', {0: 'Large', 1: 'Medium', 2: 'Small'}),
    11: _withMap('EasyShootingMode', {
      0: 'Full Auto',
      1: 'Manual',
      2: 'Landscape',
      3: 'Fast Shutter',
      4: 'Slow Shutter',
      5: 'Night',
      6: 'B&W',
      7: 'Sepia',
      8: 'Portrait',
      9: 'Sports',
      10: 'Macro/Close-Up',
      11: 'Pan Focus',
      51: 'High Dynamic Range',
    }),
    12: _withMap('DigitalZoom', {0: 'None', 1: '2x', 2: '4x', 3: 'Other'}),
    13: _withMap('Contrast', {0xFFFF: 'Low', 0: 'Normal', 1: 'High'}),
    14: _withMap('Saturation', {0xFFFF: 'Low', 0: 'Normal', 1: 'High'}),
    15: _withMap('Sharpness', {0xFFFF: 'Low', 0: 'Normal', 1: 'High'}),
    16: _withMap('ISO', {
      0: 'See ISOSpeedRatings Tag',
      15: 'Auto',
      16: '50',
      17: '100',
      18: '200',
      19: '400',
    }),
    17: _withMap('MeteringMode', {
      0: 'Default',
      1: 'Spot',
      2: 'Average',
      3: 'Evaluative',
      4: 'Partial',
      5: 'Center-weighted',
    }),
    18: _withMap('FocusType', {
      0: 'Manual',
      1: 'Auto',
      3: 'Close-Up (Macro)',
      8: 'Locked (Pan Mode)',
    }),
    19: _withMap('AFPointSelected', {
      0x3000: 'None (MF)',
      0x3001: 'Auto-Selected',
      0x3002: 'Right',
      0x3003: 'Center',
      0x3004: 'Left',
    }),
    20: _withMap('ExposureMode', {
      0: 'Easy Shooting',
      1: 'Program',
      2: 'Tv-priority',
      3: 'Av-priority',
      4: 'Manual',
      5: 'A-DEP',
    }),
    22: _make('LensType'),
    23: _make('LongFocalLengthOfLensInFocalUnits'),
    24: _make('ShortFocalLengthOfLensInFocalUnits'),
    25: _make('FocalUnitsPerMM'),
    28: _withMap('FlashActivity', {0: 'Did Not Fire', 1: 'Fired'}),
    29: _withMap('FlashDetails', {
      0: 'Manual',
      1: 'TTL',
      2: 'A-TTL',
      3: 'E-TTL',
      4: 'FP Sync Enabled',
      7: '2nd("Rear")-Curtain Sync Used',
      11: 'FP Sync Used',
      13: 'Internal Flash',
      14: 'External E-TTL',
    }),
    32: _withMap('FocusMode', {0: 'Single', 1: 'Continuous', 8: 'Manual'}),
    33: _withMap('AESetting', {
      0: 'Normal AE',
      1: 'Exposure Compensation',
      2: 'AE Lock',
      3: 'AE Lock + Exposure Comp.',
      4: 'No AE',
    }),
    34: _withMap('ImageStabilization', {
      0: 'Off',
      1: 'On',
      2: 'Shoot Only',
      3: 'Panning',
      4: 'Dynamic',
      256: 'Off',
      257: 'On',
      258: 'Shoot Only',
      259: 'Panning',
      260: 'Dynamic',
    }),
    39: _withMap('SpotMeteringMode', {
      0: 'Center',
      1: 'AF Point',
    }),
    41: _withMap('ManualFlashOutput', {
      0x0: 'n/a',
      0x500: 'Full',
      0x502: 'Medium',
      0x504: 'Low',
      0x7fff: 'n/a',
    }),
  };

  // 0x0004
  static Map<int, MakerTag> shotInfo = {
    7: _withMap('WhiteBalance', {
      0: 'Auto',
      1: 'Sunny',
      2: 'Cloudy',
      3: 'Tungsten',
      4: 'Fluorescent',
      5: 'Flash',
      6: 'Custom',
    }),
    8: _withMap('SlowShutter', {
      -1: 'n/a',
      0: 'Off',
      1: 'Night Scene',
      2: 'On',
      3: 'None',
    }),
    9: _make('SequenceNumber'),
    14: _make('AFPointUsed'),
    15: _withMap('FlashBias', {
      0xFFC0: '-2 EV',
      0xFFCC: '-1.67 EV',
      0xFFD0: '-1.50 EV',
      0xFFD4: '-1.33 EV',
      0xFFE0: '-1 EV',
      0xFFEC: '-0.67 EV',
      0xFFF0: '-0.50 EV',
      0xFFF4: '-0.33 EV',
      0x0000: '0 EV',
      0x000c: '0.33 EV',
      0x0010: '0.50 EV',
      0x0014: '0.67 EV',
      0x0020: '1 EV',
      0x002c: '1.33 EV',
      0x0030: '1.50 EV',
      0x0034: '1.67 EV',
      0x0040: '2 EV',
    }),
    19: _make('SubjectDistance'),
  };

  // 0x0026
  static Map<int, MakerTag> afInfo2 = {
    2: _withMap('AFAreaMode', {
      0: 'Off (Manual Focus)',
      2: 'Single-point AF',
      4: 'Multi-point AF or AI AF',
      5: 'Face Detect AF',
      6: 'Face + Tracking',
      7: 'Zone AF',
      8: 'AF Point Expansion',
      9: 'Spot AF',
      11: 'Flexizone Multi',
      13: 'Flexizone Single',
    }),
    3: _make('NumAFPoints'),
    4: _make('ValidAFPoints'),
    5: _make('CanonImageWidth'),
  };

  // 0x0093
  static Map<int, MakerTag> fileInfo = {
    1: _make('FileNumber'),
    3: _withMap('BracketMode', {
      0: 'Off',
      1: 'AEB',
      2: 'FEB',
      3: 'ISO',
      4: 'WB',
    }),
    4: _make('BracketValue'),
    5: _make('BracketShotNumber'),
    6: _withMap('RawJpgQuality', {
      0xFFFF: 'n/a',
      1: 'Economy',
      2: 'Normal',
      3: 'Fine',
      4: 'RAW',
      5: 'Superfine',
      130: 'Normal Movie',
    }),
    7: _withMap('RawJpgSize', {
      0: 'Large',
      1: 'Medium',
      2: 'Small',
      5: 'Medium 1',
      6: 'Medium 2',
      7: 'Medium 3',
      8: 'Postcard',
      9: 'Widescreen',
      10: 'Medium Widescreen',
      14: 'Small 1',
      15: 'Small 2',
      16: 'Small 3',
      128: '640x480 Movie',
      129: 'Medium Movie',
      130: 'Small Movie',
      137: '1280x720 Movie',
      142: '1920x1080 Movie',
    }),
    8: _withMap('LongExposureNoiseReduction2', {
      0: 'Off',
      1: 'On (1D)',
      2: 'On',
      3: 'Auto',
    }),
    9: _withMap('WBBracketMode', {
      0: 'Off',
      1: 'On (shift AB)',
      2: 'On (shift GM)',
    }),
    12: _make('WBBracketValueAB'),
    13: _make('WBBracketValueGM'),
    14: _withMap('FilterEffect', {
      0: 'None',
      1: 'Yellow',
      2: 'Orange',
      3: 'Red',
      4: 'Green',
    }),
    15: _withMap('ToningEffect', {
      0: 'None',
      1: 'Sepia',
      2: 'Blue',
      3: 'Purple',
      4: 'Green',
    }),
    16: _make('MacroMagnification'),
    19: _withMap('LiveViewShooting', {0: 'Off', 1: 'On'}),
    25: _withMap('FlashExposureLock', {0: 'Off', 1: 'On'}),
  };

  static String addOneFunc(int value) {
    return '${value + 1}';
  }

  static String subtractOneFunc(int value) {
    return '${value - 1}';
  }

  static String convertTempFunc(int value) {
    return sprintf('%d C', [value - 128]);
  }

  // CameraInfo data structures have variable sized members. Each entry here is:
  // byte offset:  (item name, data item type, decoding map).
  // Note that the data item type is fed directly to struct.unpack at the
  // specified offset.
  static const cameraInfoTagName = 'MakerNote Tag 0x000D';

  // A map of regular expressions on 'Image Model' to the CameraInfo spec
  static Map<String, Map<int, CameraInfo>> cameraInfoModelMap = {
    r'EOS 5D$': {
      23: const CameraInfo('CameraTemperature', 1, convertTempFunc),
      204: const CameraInfo('DirectoryIndex', 4, subtractOneFunc),
      208: const CameraInfo('FileIndex', 2, addOneFunc),
    },
    r'EOS 5D Mark II$': {
      25: const CameraInfo('CameraTemperature', 1, convertTempFunc),
      443: const CameraInfo('FileIndex', 4, addOneFunc),
      455: const CameraInfo('DirectoryIndex', 4, subtractOneFunc),
    },
    r'EOS 5D Mark III$': {
      27: const CameraInfo('CameraTemperature', 1, convertTempFunc),
      652: const CameraInfo('FileIndex', 4, addOneFunc),
      656: const CameraInfo('FileIndex2', 4, addOneFunc),
      664: const CameraInfo('DirectoryIndex', 4, subtractOneFunc),
      668: const CameraInfo('DirectoryIndex2', 4, subtractOneFunc),
    },
    r'\b(600D|REBEL T3i|Kiss X5)\b': {
      25: const CameraInfo('CameraTemperature', 1, convertTempFunc),
      475: const CameraInfo('FileIndex', 4, addOneFunc),
      487: const CameraInfo('DirectoryIndex', 4, subtractOneFunc),
    },
  };
}

class CameraInfo {
  final String tagName;
  final int tagSize;
  final String Function(int) function;

  const CameraInfo(
    this.tagName,
    this.tagSize,
    this.function,
  );
}
