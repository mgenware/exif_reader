// ignore_for_file: strict_raw_type

import 'dart:typed_data';

import 'helpers/uint8list_extension.dart';

/// Represents a tag in an Image File Directory (IFD) with its associated data.
///
/// Contains the tag ID, type, printable value, and the raw values.
class IfdTag {
  /// Tag ID number.
  final int tag;

  /// The type of the tag (e.g., ASCII, Short, Long, etc.).
  final String tagType;

  /// Printable version of the tag's data.
  final String printable;

  /// List of data items (int, char, number, or Ratio).
  final IfdValues values;

  /// Creates an [IfdTag] with the given properties.
  IfdTag({
    required this.tag,
    required this.tagType,
    required this.printable,
    required this.values,
  });

  @override
  String toString() => printable;
}

/// Abstract base class for IFD value types.
///
/// Subclasses represent different types of EXIF tag values.
abstract class IfdValues {
  /// Creates an [IfdValues] instance.
  const IfdValues();

  /// Returns the values as a list.
  List toList();

  /// Returns the number of items in the values.
  int get length;

  /// Returns the first value as an integer.
  int firstAsInt();
}

/// Represents an empty set of IFD values.
class IfdNone extends IfdValues {
  /// Creates an empty [IfdNone] instance.
  const IfdNone();

  @override
  List toList() => [];

  @override
  int get length => 0;

  @override
  int firstAsInt() => 0;

  @override
  String toString() => '[]';
}

/// Represents a set of [Ratio] values in an IFD tag.
class IfdRatios extends IfdValues {
  /// The list of [Ratio] values.
  final List<Ratio> ratios;

  /// Creates an [IfdRatios] instance from a list of ratios.
  const IfdRatios(this.ratios);

  @override
  List toList() => ratios;

  @override
  int get length => ratios.length;

  @override
  int firstAsInt() => ratios[0].toInt();

  @override
  String toString() => ratios.toString();
}

/// Represents a set of integer values in an IFD tag.
class IfdInts extends IfdValues {
  /// The list of integer values.
  final List<int> ints;

  /// Creates an [IfdInts] instance from a list of integers.
  const IfdInts(this.ints);

  @override
  List toList() => ints;

  @override
  int get length => ints.length;

  @override
  int firstAsInt() => ints[0];

  @override
  String toString() => ints.toString();
}

/// Represents a set of byte values in an IFD tag.
class IfdBytes extends IfdValues {
  /// The bytes stored in this value.
  final Uint8List bytes;

  /// Creates an [IfdBytes] instance from a [Uint8List].
  IfdBytes(this.bytes);

  /// Creates an empty [IfdBytes] instance.
  IfdBytes.empty() : bytes = Uint8List(0);

  /// Creates an [IfdBytes] instance from a list of integers.
  IfdBytes.fromList(List<int> list) : bytes = Uint8List.fromList(list);

  @override
  List toList() => bytes;

  @override
  int get length => bytes.length;

  @override
  int firstAsInt() => bytes[0];

  @override
  String toString() => bytes.toHex(separator: ' ');
}

/// Represents a rational number (numerator/denominator) for EXIF tags.
/// Automatically reduces itself to the lowest common denominator for printing.
class Ratio {
  /// The numerator of the ratio.
  final int numerator;

  /// The denominator of the ratio.
  final int denominator;

  /// Creates a [Ratio] and reduces it to the lowest terms.
  factory Ratio(int num, int den) {
    if (den < 0) {
      num *= -1;
      den *= -1;
    }

    final d = num.gcd(den);
    if (d > 1) {
      num = num ~/ d;
      den = den ~/ d;
    }

    return Ratio._internal(num, den);
  }

  /// Internal constructor for [Ratio].
  Ratio._internal(this.numerator, this.denominator);

  @override
  String toString() =>
      (denominator == 1) ? '$numerator' : '$numerator/$denominator';

  /// Converts the ratio to an integer using integer division.
  int toInt() => numerator ~/ denominator;

  /// Converts the ratio to a double.
  double toDouble() => numerator / denominator;
}

/// Represents the extracted EXIF data, including tags and warnings.
class ExifData {
  /// The map of tag names to [IfdTag] objects.
  final Map<String, IfdTag> tags;

  /// List of warnings encountered during EXIF extraction.
  final List<String> warnings;

  /// Creates an [ExifData] instance with tags and warnings.
  const ExifData(this.tags, this.warnings);

  /// Creates an [ExifData] instance with a single warning and no tags.
  ExifData.withWarning(String warning) : this(const {}, [warning]);

  /// Merges two [ExifData] instances into one.
  static ExifData merge(ExifData a, ExifData b) {
    a.tags.addAll(b.tags);
    a.warnings.addAll(b.warnings);
    return a;
  }
}
