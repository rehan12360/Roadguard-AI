import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/hazard.dart';

class PdfExportService {
  /// Generates AI-like insights based on the hazard data.
  static String generateAIInsights(List<Hazard> hazards) {
    if (hazards.isEmpty) {
      return 'No hazards detected in the current zone. Road network is clear and optimal.';
    }

    int criticalCount = hazards.where((h) => h.isCritical).length;
    int verifiedCount = hazards.where((h) => h.verifications > 1).length;
    
    // Most common hazard type
    var typeCounts = <String, int>{};
    for (var h in hazards) {
      typeCounts[h.hazardType] = (typeCounts[h.hazardType] ?? 0) + 1;
    }
    var commonType = '';
    var maxCount = 0;
    typeCounts.forEach((k, v) {
      if (v > maxCount) {
        maxCount = v;
        commonType = k;
      }
    });

    return 'Analysis of ${hazards.length} total incidents reveals that $criticalCount require immediate attention. '
        'The most prevalent issue is "$commonType" ($maxCount incidents). '
        'Peer consensus is strong with $verifiedCount hazards cross-verified by multiple vehicles. '
        'Recommendation: Deploy repair crews to critical zones to restore optimal road flow.';
  }

  static Future<void> exportAndShareReport(List<Hazard> hazards) async {
    final pdf = pw.Document();

    // Generate simulated AI Insights
    final insights = generateAIInsights(hazards);

    // Filter to top hazards for the table
    final sortedHazards = List<Hazard>.from(hazards);
    sortedHazards.sort((a, b) => b.confidence.compareTo(a.confidence));
    final topHazards = sortedHazards.take(10).toList();

    // Define standard theme
    final theme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.interRegular(),
      bold: await PdfGoogleFonts.interBold(),
    );

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(),
            pw.SizedBox(height: 20),
            _buildAIInsights(insights),
            pw.SizedBox(height: 30),
            _buildHazardsTable(topHazards),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'RoadGuard_Smart_Report.pdf',
    );
  }

  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'RoadGuard AI',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#FF2A5F'),
              ),
            ),
            pw.Text(
              'Project-Specific Report',
              style: pw.TextStyle(
                fontSize: 14,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Automated Road Network Analysis',
          style: const pw.TextStyle(
            fontSize: 16,
            color: PdfColors.grey800,
          ),
        ),
        pw.Divider(color: PdfColor.fromHex('#00F2FE'), thickness: 2),
      ],
    );
  }

  static pw.Widget _buildAIInsights(String insights) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'AI Insights & Evaluation',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            insights,
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey800,
              lineSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHazardsTable(List<Hazard> hazards) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Prioritized Incidents',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColors.blueGrey800,
          ),
          cellHeight: 30,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.center,
          },
          headers: ['Hazard Type', 'Severity', 'AI Confidence', 'Verifications'],
          data: hazards.map((h) {
            return [
              h.hazardType.toUpperCase(),
              h.isCritical ? 'CRITICAL' : 'MEDIUM',
              '\${(h.confidence * 100).toInt()}%',
              h.verifications.toString(),
            ];
          }).toList(),
        ),
      ],
    );
  }
}
