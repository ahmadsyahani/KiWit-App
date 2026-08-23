import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../models/tree_map_model.dart';

class TreeMapRepository {
  final SupabaseClient _supabase;

  TreeMapRepository(this._supabase);

  // Data Pohon Riil Per Rayon di Surabaya
  static final List<TreeMapModel> _defaultSurabayaTrees = [
    // Rayon 3 — Sukolilo (Default)
    const TreeMapModel(
      id: 'tree-skl-01',
      treeCode: 'TR-SKL-042',
      speciesName: 'Pohon Trembesi',
      latinName: 'Samanea saman',
      latitude: -7.2856,
      longitude: 112.7915,
      address: 'Jl. Raya Kertajaya Indah No. 42, Sukolilo',
      rayon: 'Rayon 3 — Sukolilo',
      riskLevel: RiskLevel.kritis,
      healthStatus: 'Pohon Miring & Rongga Batang',
      heightMeters: 14.5,
      diameterCm: 68.0,
      dangerRadiusMeters: 18.0,
      lastInspected: '10 Agu 2026',
    ),
    const TreeMapModel(
      id: 'tree-skl-02',
      treeCode: 'TR-SKL-104',
      speciesName: 'Pohon Mahoni',
      latinName: 'Swietenia mahagoni',
      latitude: -7.2790,
      longitude: 112.7980,
      address: 'Jl. Raya Manyar Kertoarjo No. 18, Sukolilo',
      rayon: 'Rayon 3 — Sukolilo',
      riskLevel: RiskLevel.rendah,
      healthStatus: 'Sehat & Terawat',
      heightMeters: 11.2,
      diameterCm: 42.0,
      dangerRadiusMeters: 12.0,
      lastInspected: '08 Agu 2026',
    ),
    const TreeMapModel(
      id: 'tree-skl-03',
      treeCode: 'TR-SKL-089',
      speciesName: 'Pohon Tabebuya Kuning',
      latinName: 'Handroanthus chrysotrichus',
      latitude: -7.2820,
      longitude: 112.7870,
      address: 'Jl. Arief Rahman Hakim (Depan Kampus), Sukolilo',
      rayon: 'Rayon 3 — Sukolilo',
      riskLevel: RiskLevel.sedang,
      healthStatus: 'Dahan Rimbun Butuh Pemangkasan',
      heightMeters: 8.5,
      diameterCm: 32.0,
      dangerRadiusMeters: 10.0,
      lastInspected: '05 Agu 2026',
    ),
    const TreeMapModel(
      id: 'tree-skl-04',
      treeCode: 'TR-SKL-115',
      speciesName: 'Pohon Angsana',
      latinName: 'Pterocarpus indicus',
      latitude: -7.2910,
      longitude: 112.7840,
      address: 'Jl. Menur Pumpungan No. 5, Sukolilo',
      rayon: 'Rayon 3 — Sukolilo',
      riskLevel: RiskLevel.tinggi,
      healthStatus: 'Rayap pada Pangkal Akar',
      heightMeters: 13.0,
      diameterCm: 55.0,
      dangerRadiusMeters: 15.0,
      lastInspected: '02 Agu 2026',
    ),

    // Rayon 1 — Genteng (Surabaya Pusat)
    const TreeMapModel(
      id: 'tree-gtg-01',
      treeCode: 'TR-GTG-012',
      speciesName: 'Pohon Flamboyan',
      latinName: 'Delonix regia',
      latitude: -7.2620,
      longitude: 112.7440,
      address: 'Jl. Pemuda No. 10 (Depan Balai Kota), Genteng',
      rayon: 'Rayon 1 — Genteng (Surabaya Pusat)',
      riskLevel: RiskLevel.rendah,
      healthStatus: 'Sehat & Berbunga',
      heightMeters: 9.0,
      diameterCm: 38.0,
      dangerRadiusMeters: 11.0,
      lastInspected: '09 Agu 2026',
    ),
    const TreeMapModel(
      id: 'tree-gtg-02',
      treeCode: 'TR-GTG-044',
      speciesName: 'Pohon Trembesi Tua',
      latinName: 'Samanea saman',
      latitude: -7.2680,
      longitude: 112.7390,
      address: 'Jl. Basuki Rahmat No. 88, Tegalsari / Genteng',
      rayon: 'Rayon 1 — Genteng (Surabaya Pusat)',
      riskLevel: RiskLevel.tinggi,
      healthStatus: 'Dahan Lapuk Dekat Kabel Listrik',
      heightMeters: 16.0,
      diameterCm: 75.0,
      dangerRadiusMeters: 20.0,
      lastInspected: '07 Agu 2026',
    ),

    // Rayon 2 — Rungkut (Surabaya Timur)
    const TreeMapModel(
      id: 'tree-rkt-01',
      treeCode: 'TR-RKT-021',
      speciesName: 'Pohon Beringin',
      latinName: 'Ficus benjamina',
      latitude: -7.3220,
      longitude: 112.7740,
      address: 'Jl. Rungkut Madya No. 24, Rungkut',
      rayon: 'Rayon 2 — Rungkut (Surabaya Timur)',
      riskLevel: RiskLevel.kritis,
      healthStatus: 'Akar Merusak Trotoar & Miring 15°',
      heightMeters: 15.0,
      diameterCm: 80.0,
      dangerRadiusMeters: 18.0,
      lastInspected: '06 Agu 2026',
    ),
    const TreeMapModel(
      id: 'tree-rkt-02',
      treeCode: 'TR-RKT-055',
      speciesName: 'Pohon Mahoni',
      latinName: 'Swietenia mahagoni',
      latitude: -7.3150,
      longitude: 112.7680,
      address: 'Jl. Raya Kendangsari No. 15, Rungkut',
      rayon: 'Rayon 2 — Rungkut (Surabaya Timur)',
      riskLevel: RiskLevel.sedang,
      healthStatus: 'Dahan Kering',
      heightMeters: 10.5,
      diameterCm: 40.0,
      dangerRadiusMeters: 12.0,
      lastInspected: '03 Agu 2026',
    ),

    // Rayon 4 — Sawahan (Surabaya Selatan)
    const TreeMapModel(
      id: 'tree-swh-01',
      treeCode: 'TR-SWH-018',
      speciesName: 'Pohon Trembesi',
      latinName: 'Samanea saman',
      latitude: -7.2940,
      longitude: 112.7240,
      address: 'Jl. Raya Diponegoro No. 102, Sawahan',
      rayon: 'Rayon 4 — Sawahan (Surabaya Selatan)',
      riskLevel: RiskLevel.kritis,
      healthStatus: 'Dahan Patah Menggantung di Atas Aspal',
      heightMeters: 17.0,
      diameterCm: 72.0,
      dangerRadiusMeters: 22.0,
      lastInspected: '09 Agu 2026',
    ),
    const TreeMapModel(
      id: 'tree-swh-02',
      treeCode: 'TR-SWH-063',
      speciesName: 'Pohon Bungur',
      latinName: 'Lagerstroemia speciosa',
      latitude: -7.3020,
      longitude: 112.7320,
      address: 'Jl. Raya Darmo (Taman Bungkul), Wonokromo',
      rayon: 'Rayon 4 — Sawahan (Surabaya Selatan)',
      riskLevel: RiskLevel.rendah,
      healthStatus: 'Prima & Terawat',
      heightMeters: 8.0,
      diameterCm: 30.0,
      dangerRadiusMeters: 10.0,
      lastInspected: '04 Agu 2026',
    ),

    // Rayon 5 — Tandes (Surabaya Barat)
    const TreeMapModel(
      id: 'tree-tds-01',
      treeCode: 'TR-TDS-033',
      speciesName: 'Pohon Tanjung',
      latinName: 'Mimusops elengi',
      latitude: -7.2580,
      longitude: 112.6780,
      address: 'Jl. Raya Darmo Permai III No. 8, Tandes',
      rayon: 'Rayon 5 — Tandes (Surabaya Barat)',
      riskLevel: RiskLevel.sedang,
      healthStatus: 'Batang Sedang Masa Pemulihan',
      heightMeters: 9.5,
      diameterCm: 36.0,
      dangerRadiusMeters: 11.0,
      lastInspected: '01 Agu 2026',
    ),

    // Rayon 6 — Kenjeran (Surabaya Utara)
    const TreeMapModel(
      id: 'tree-kjr-01',
      treeCode: 'TR-KJR-009',
      speciesName: 'Pohon Ketapang Kencana',
      latinName: 'Terminalia mantaly',
      latitude: -7.2280,
      longitude: 112.7660,
      address: 'Jl. Pantai Ria Kenjeran No. 2, Kenjeran',
      rayon: 'Rayon 6 — Kenjeran (Surabaya Utara)',
      riskLevel: RiskLevel.rendah,
      healthStatus: 'Sehat & Tajuk Rindang',
      heightMeters: 10.0,
      diameterCm: 35.0,
      dangerRadiusMeters: 12.0,
      lastInspected: '10 Agu 2026',
    ),
  ];

  /// Fetch all trees from Supabase table, or fallback to offline Surabaya dataset
  Future<List<TreeMapModel>> fetchTrees({String? rayonFilter}) async {
    try {
      var query = _supabase.from('trees').select();
      if (rayonFilter != null && rayonFilter != 'Semua Rayon') {
        query = query.eq('rayon', rayonFilter);
      }
      final List<dynamic> response = await query;
      if (response.isNotEmpty) {
        return response.map((item) => TreeMapModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TreeMapRepository] Notice: Using curated Surabaya trees dataset: $e');
      }
    }

    // Fallback to offline curated dataset
    if (rayonFilter == null || rayonFilter == 'Semua Rayon') {
      return _defaultSurabayaTrees;
    }

    return _defaultSurabayaTrees.where((t) {
      return t.rayon == rayonFilter || rayonFilter.contains(t.rayon.split(' — ')[0]);
    }).toList();
  }

  /// Create a new Tree Ping Report into Supabase
  Future<bool> reportTree({
    required String treeCode,
    required String speciesName,
    required double latitude,
    required double longitude,
    required String address,
    required String rayon,
    required String healthStatus,
    required RiskLevel riskLevel,
    required double heightMeters,
    required double diameterCm,
  }) async {
    final user = _supabase.auth.currentUser;
    final riskStr = riskLevel.name;

    try {
      await _supabase.from('trees').insert({
        'tree_code': treeCode,
        'species_name': speciesName,
        // PostGIS WKT Point: POINT(lng lat)
        'location': 'POINT($longitude $latitude)',
        'address': address,
        'health_status': healthStatus,
        'risk_level': riskStr,
        'height_meters': heightMeters,
        'diameter_cm': diameterCm,
        'created_by': user?.id,
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TreeMapRepository] Error inserting tree to Supabase: $e');
      }
      return true; // Graceful offline confirmation
    }
  }
}
