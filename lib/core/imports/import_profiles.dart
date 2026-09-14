import 'package:m3uxtream_player/core/imports/import_limits.dart';

class ImportProfiles {
  ImportProfiles._();

  static const int _mib = 1024 * 1024;
  static const int _gib = 1024 * _mib;

  static const m3u = ImportLimits(
    maxTransportBytes: 64 * _mib,
    maxEndpointTransportBytes: 64 * _mib,
    maxDecodedBytes: 128 * _mib,
    maxRecords: 250000,
    maxLineRecords: 1000000,
    maxChannelRecords: 250000,
    maxCategoryRecords: 250000,
    maxFieldBytes: 16 * 1024,
    maxPersistedRows: 250000,
    maxXmlDepth: 0,
    maxDuration: Duration(minutes: 10),
  );

  static const xtream = ImportLimits(
    maxTransportBytes: 256 * _mib,
    maxEndpointTransportBytes: 128 * _mib,
    maxDecodedBytes: 384 * _mib,
    maxRecords: 500000,
    maxLineRecords: 500000,
    maxChannelRecords: 500000,
    maxCategoryRecords: 500000,
    maxFieldBytes: 16 * 1024,
    maxPersistedRows: 500000,
    maxXmlDepth: 0,
    maxDuration: Duration(minutes: 10),
  );

  static const xmltv = ImportLimits(
    maxTransportBytes: 128 * _mib,
    maxEndpointTransportBytes: 128 * _mib,
    maxDecodedBytes: _gib,
    maxRecords: 2000000,
    maxLineRecords: 2000000,
    maxChannelRecords: 250000,
    maxCategoryRecords: 0,
    maxFieldBytes: 32 * 1024,
    maxPersistedRows: 2250000,
    maxXmlDepth: 128,
    maxDuration: Duration(minutes: 20),
  );

  /// Finite ceilings for future advanced profiles and boundary tests.
  static const hardM3u = ImportLimits(
    maxTransportBytes: 256 * _mib,
    maxEndpointTransportBytes: 256 * _mib,
    maxDecodedBytes: 512 * _mib,
    maxRecords: 1000000,
    maxLineRecords: 4000000,
    maxChannelRecords: 1000000,
    maxCategoryRecords: 1000000,
    maxFieldBytes: 64 * 1024,
    maxPersistedRows: 1000000,
    maxXmlDepth: 0,
    maxDuration: Duration(minutes: 20),
  );

  static const hardXtream = ImportLimits(
    maxTransportBytes: 512 * _mib,
    maxEndpointTransportBytes: 256 * _mib,
    maxDecodedBytes: 768 * _mib,
    maxRecords: 1000000,
    maxLineRecords: 1000000,
    maxChannelRecords: 1000000,
    maxCategoryRecords: 1000000,
    maxFieldBytes: 64 * 1024,
    maxPersistedRows: 1000000,
    maxXmlDepth: 0,
    maxDuration: Duration(minutes: 20),
  );

  static const hardXmltv = ImportLimits(
    maxTransportBytes: 512 * _mib,
    maxEndpointTransportBytes: 512 * _mib,
    maxDecodedBytes: 2 * _gib,
    maxRecords: 5000000,
    maxLineRecords: 5000000,
    maxChannelRecords: 500000,
    maxCategoryRecords: 0,
    maxFieldBytes: 128 * 1024,
    maxPersistedRows: 5500000,
    maxXmlDepth: 256,
    maxDuration: Duration(minutes: 40),
  );
}
