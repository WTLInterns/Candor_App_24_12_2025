import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_saver/file_saver.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../services/api_client.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final _invoiceNoCtrl = TextEditingController();
  DateTime? _invoiceDate = DateTime.now();
  DateTime? _dueDate = DateTime.now();

  final _billedByName = TextEditingController();
  final _billedByAddress = TextEditingController();
  final _billedByGstin = TextEditingController();
  final _billedByMobile = TextEditingController();
  final _billedByEmail = TextEditingController();

  final _billedToName = TextEditingController();
  final _billedToAddress = TextEditingController();
  final _billedToGstin = TextEditingController();
  final _billedToMobile = TextEditingController();
  final _billedToEmail = TextEditingController();

  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _ifscCode = TextEditingController();
  final _accountType = TextEditingController();
  final _bankName = TextEditingController();
  final _upiId = TextEditingController();

  final _termsCtrl = TextEditingController();

  final _itemNameCtrl = TextEditingController();
  final _itemQtyCtrl = TextEditingController();
  final _itemRateCtrl = TextEditingController();

  final List<_InvoiceItem> _items = [];
  bool _withGst = true;

  XFile? _logo;
  XFile? _stamp;

  bool _isUploading = false;

  @override
  void dispose() {
    _invoiceNoCtrl.dispose();
    _billedByName.dispose();
    _billedByAddress.dispose();
    _billedByGstin.dispose();
    _billedByMobile.dispose();
    _billedByEmail.dispose();
    _billedToName.dispose();
    _billedToAddress.dispose();
    _billedToGstin.dispose();
    _billedToMobile.dispose();
    _billedToEmail.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    _ifscCode.dispose();
    _accountType.dispose();
    _bankName.dispose();
    _upiId.dispose();
    _termsCtrl.dispose();
    _itemNameCtrl.dispose();
    _itemQtyCtrl.dispose();
    _itemRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePreviewPdf() async {
    try {
      final bytes = await _buildPdfBytes();
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preview failed please try again'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Create Invoice'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _headerSection(
                      'Invoice Details',
                      Colors.lightBlue,
                      _buildInvoiceDetails(),
                    ),
                    const SizedBox(height: 12),
                    _headerSection('Billed By', Colors.green, _buildBilledBy()),
                    const SizedBox(height: 12),
                    _headerSection(
                      'Billed To',
                      Colors.orange,
                      _buildBilledTo(),
                    ),
                    const SizedBox(height: 12),
                    _itemHeader(),
                    _buildItemsList(),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: _showAddItemDialog,
                        child: const Text('Add Item'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _headerSection(
                      'Bank / UPI',
                      Colors.red,
                      _buildBankSection(),
                    ),
                    const SizedBox(height: 12),
                    _headerSection(
                      'Terms and Conditions',
                      Colors.blue,
                      _buildTermsSection(),
                    ),
                    const SizedBox(height: 12),
                    _buildLogoStampRow(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _handlePreviewPdf,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Preview PDF'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _handleDownloadAndUpload,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: Text(
                        _isUploading ? 'Please wait...' : 'Download PDF',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerSection(String title, Color color, Widget child) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  Widget _buildInvoiceDetails() {
    return Column(
      children: [
        _rowFields([_textField('Invoice No', _invoiceNoCtrl)]),
        const SizedBox(height: 8),
        _rowFields([
          _dateField(
            'Invoice Date',
            _invoiceDate,
            (d) => setState(() => _invoiceDate = d),
          ),
          _dateField('Due Date', _dueDate, (d) => setState(() => _dueDate = d)),
        ]),
      ],
    );
  }

  Widget _buildBilledBy() {
    return Column(
      children: [
        _rowFields([_textField('Name', _billedByName)]),
        const SizedBox(height: 8),
        _rowFields([_textField('Address', _billedByAddress)]),
        const SizedBox(height: 8),
        _rowFields([
          _textField('GSTIN', _billedByGstin),
          _textField(
            'Mobile No',
            _billedByMobile,
            keyboardType: TextInputType.phone,
          ),
        ]),
        const SizedBox(height: 8),
        _rowFields([
          _textField(
            'Email',
            _billedByEmail,
            keyboardType: TextInputType.emailAddress,
          ),
        ]),
      ],
    );
  }

  Widget _buildBilledTo() {
    return Column(
      children: [
        _rowFields([_textField('Name', _billedToName)]),
        const SizedBox(height: 8),
        _rowFields([_textField('Address', _billedToAddress)]),
        const SizedBox(height: 8),
        _rowFields([
          _textField('GSTIN', _billedToGstin),
          _textField(
            'Mobile No',
            _billedToMobile,
            keyboardType: TextInputType.phone,
          ),
        ]),
        const SizedBox(height: 8),
        _rowFields([
          _textField(
            'Email',
            _billedToEmail,
            keyboardType: TextInputType.emailAddress,
          ),
        ]),
      ],
    );
  }

  Widget _itemHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Expanded(child: Text('Item')),
          ChoiceChip(
            label: const Text('GST'),
            selected: _withGst,
            onSelected: (v) => setState(() => _withGst = true),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Without GST'),
            selected: !_withGst,
            onSelected: (v) => setState(() => _withGst = false),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    final total = _computeTotal();
    return Column(
      children: [
        const SizedBox(height: 8),
        if (_items.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('No items added'),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Rate')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (int i = 0; i < _items.length; i++)
                  DataRow(
                    cells: [
                      DataCell(Text(_items[i].name)),
                      DataCell(Text(_items[i].qty.toString())),
                      DataCell(Text(_items[i].rate.toStringAsFixed(2))),
                      DataCell(Text(_items[i].amount.toStringAsFixed(2))),
                      DataCell(
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            setState(() {
                              _items.removeAt(i);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [Text('Total: ${total.toStringAsFixed(2)}')],
        ),
      ],
    );
  }

  Widget _buildBankSection() {
    return Column(
      children: [
        _rowFields([_textField('Account Name', _accountName)]),
        const SizedBox(height: 8),
        _rowFields([
          _textField(
            'Account Number',
            _accountNumber,
            keyboardType: TextInputType.number,
          ),
          _textField('IFSC Code', _ifscCode),
        ]),
        const SizedBox(height: 8),
        _rowFields([
          _textField('Account Type', _accountType),
          _textField('Bank Name', _bankName),
        ]),
        const SizedBox(height: 8),
        _rowFields([_textField('UPI ID', _upiId)]),
      ],
    );
  }

  Widget _buildTermsSection() {
    return TextField(
      controller: _termsCtrl,
      maxLines: 4,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Enter terms and conditions',
      ),
    );
  }

  Widget _buildLogoStampRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pickImage(isLogo: true),
            child: const Text('Company Logo'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pickImage(isLogo: false),
            child: const Text('Upload Stamp'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage({required bool isLogo}) async {
    final status = await Permission.photos.request();
    if (!status.isGranted) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        if (isLogo) {
          _logo = file;
        } else {
          _stamp = file;
        }
      });
    }
  }

  Widget _textField(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Expanded(
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dateField(
    String label,
    DateTime? date,
    ValueChanged<DateTime?> onPick,
  ) {
    final text = date != null ? DateFormat('dd/MM/yyyy').format(date) : '';
    return Expanded(
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? now,
            firstDate: DateTime(now.year - 5),
            lastDate: DateTime(now.year + 5),
          );
          onPick(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          child: Text(text.isEmpty ? 'Select date' : text),
        ),
      ),
    );
  }

  Widget _rowFields(List<Widget> children) {
    return Row(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          children[i],
        ],
      ],
    );
  }

  void _showAddItemDialog() {
    _itemNameCtrl.clear();
    _itemQtyCtrl.clear();
    _itemRateCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _itemNameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _itemQtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _itemRateCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Rate'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _itemNameCtrl.text.trim();
                final qty = int.tryParse(_itemQtyCtrl.text.trim());
                final rate = double.tryParse(_itemRateCtrl.text.trim());
                if (name.isNotEmpty && qty != null && rate != null) {
                  setState(() {
                    _items.add(_InvoiceItem(name: name, qty: qty, rate: rate));
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  double _computeTotal() {
    final subtotal = _items.fold<double>(0.0, (sum, e) => sum + e.amount);
    if (!_withGst) return subtotal;
    final gst = subtotal * 0.18;
    return subtotal + gst;
  }

  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();
    final logoImg =
        _logo != null ? pw.MemoryImage(await _logo!.readAsBytes()) : null;
    final stampImg =
        _stamp != null ? pw.MemoryImage(await _stamp!.readAsBytes()) : null;

    pw.ThemeData? theme;
    try {
      final regularData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      final regular = pw.Font.ttf(regularData);
      final bold = pw.Font.ttf(boldData);
      theme = pw.ThemeData.withFont(base: regular, bold: bold);
    } catch (_) {
      theme = null;
    }

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) {
          final purple = PdfColor.fromInt(0xFF6C63FF);
          final greyLine = PdfColors.grey600;
          final subtotal = _items.fold<double>(0.0, (s, e) => s + e.amount);
          final cgst = _withGst ? subtotal * 0.09 : 0.0;
          final sgst = _withGst ? subtotal * 0.09 : 0.0;
          final total = subtotal + cgst + sgst;

          pw.Widget labelValue(String label, String value) => pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      label,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    flex: 2,
                  ),
                  pw.Expanded(child: pw.Text(value), flex: 5),
                ],
              );

          return [
            pw.Stack(
              children: [
                if (logoImg != null)
                  pw.Positioned(
                    right: 0,
                    top: 0,
                    child: pw.Container(
                      width: 90,
                      height: 90,
                      child: pw.Image(logoImg),
                    ),
                  ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        color: purple,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              labelValue('Invoice No #', _invoiceNoCtrl.text),
                              pw.SizedBox(height: 4),
                              labelValue(
                                'Invoice Date',
                                _fmtDate(_invoiceDate),
                              ),
                              pw.SizedBox(height: 4),
                              labelValue('Due Date', _fmtDate(_dueDate)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(height: 1, color: greyLine),

                    pw.SizedBox(height: 14),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Billed By',
                                style: pw.TextStyle(
                                  color: purple,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(_billedByName.text),
                              pw.Text(_billedByAddress.text),
                              pw.Text('GSTIN     ${_billedByGstin.text}'),
                              pw.Text('Mobile   ${_billedByMobile.text}'),
                              pw.Text('Email     ${_billedByEmail.text}'),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 24),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Billed To',
                                style: pw.TextStyle(
                                  color: purple,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(_billedToName.text),
                              pw.Text(_billedToAddress.text),
                              pw.Text('GSTIN     ${_billedToGstin.text}'),
                              pw.Text('Mobile   ${_billedToMobile.text}'),
                              pw.Text('Email     ${_billedToEmail.text}'),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 16),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: () {
                        final headers = <String>['', 'Item'];
                        final widths = <int, pw.TableColumnWidth>{
                          0: const pw.FixedColumnWidth(24),
                          1: const pw.FlexColumnWidth(3),
                        };
                        int colIndex = 2;
                        if (_withGst) {
                          headers.add('GST\nRate');
                          widths[colIndex++] = const pw.FixedColumnWidth(50);
                        }
                        headers.addAll(['Qty', 'Rate', 'Amount']);
                        widths[colIndex++] = const pw.FixedColumnWidth(36);
                        widths[colIndex++] = const pw.FixedColumnWidth(70);
                        widths[colIndex++] = const pw.FixedColumnWidth(80);
                        if (_withGst) {
                          headers.addAll(['CGST', 'SGST']);
                          widths[colIndex++] = const pw.FixedColumnWidth(70);
                          widths[colIndex++] = const pw.FixedColumnWidth(70);
                        }
                        headers.add('Total');
                        widths[colIndex] = const pw.FixedColumnWidth(90);

                        return pw.Table(
                          border: pw.TableBorder.symmetric(
                            inside: pw.BorderSide(
                              color: PdfColors.grey300,
                              width: 0.5,
                            ),
                          ),
                          columnWidths: widths,
                          children: [
                            pw.TableRow(
                              decoration: pw.BoxDecoration(color: purple),
                              children: [
                                for (final h in headers)
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      h,
                                      style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            ...List.generate(_items.length, (i) {
                              final it = _items[i];
                              final lineSubtotal = it.amount;
                              final lineCgst =
                                  _withGst ? lineSubtotal * 0.09 : 0.0;
                              final lineSgst =
                                  _withGst ? lineSubtotal * 0.09 : 0.0;
                              final lineTotal =
                                  lineSubtotal + lineCgst + lineSgst;

                              final cells = <pw.Widget>[
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text('${i + 1}'),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(it.name),
                                ),
                              ];
                              if (_withGst) {
                                cells.add(
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text('18%'),
                                  ),
                                );
                              }
                              cells.addAll([
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(it.qty.toString()),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(it.rate.toString()),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(lineSubtotal.toString()),
                                ),
                              ]);
                              if (_withGst) {
                                cells.addAll([
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(lineCgst.toString()),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(lineSgst.toString()),
                                  ),
                                ]);
                              }
                              cells.add(
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(lineTotal.toString()),
                                ),
                              );

                              return pw.TableRow(children: cells);
                            }),
                          ],
                        );
                      }(),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            'Total (in words): ${_numberToWords(total.round())} ONLY',
                          ),
                        ),
                        pw.Container(
                          width: 220,
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Text(
                                'Total (INR)  ',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.only(top: 2),
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                    bottom: pw.BorderSide(width: 1),
                                  ),
                                ),
                                child: pw.Text(
                                  total.toString(),
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 18),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Bank Details',
                                style: pw.TextStyle(
                                  color: purple,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              labelValue('Account Name:', _accountName.text),
                              labelValue(
                                'Account Number:',
                                _accountNumber.text,
                              ),
                              labelValue('IFSC:', _ifscCode.text),
                              labelValue('Account Type:', _accountType.text),
                              labelValue('Bank:', _bankName.text),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 24),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'UPI - Scan to Pay',
                                style: pw.TextStyle(
                                  color: purple,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                '(Maximum of 1 Lakh can be transferred via UPI)',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                              pw.SizedBox(height: 8),
                              if ((_upiId.text).isNotEmpty)
                                pw.Row(
                                  children: [
                                    pw.BarcodeWidget(
                                      barcode: pw.Barcode.qrCode(),
                                      data:
                                          'upi://pay?pa=${_upiId.text}&pn=${_billedByName.text}&am=${total.toStringAsFixed(2)}',
                                      width: 110,
                                      height: 110,
                                    ),
                                  ],
                                ),
                              pw.SizedBox(height: 6),
                              pw.Text('UPI ID: ${_upiId.text}'),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 18),
                    pw.Text(
                      'Terms and Conditions',
                      style: pw.TextStyle(
                        color: purple,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(_termsCtrl.text),

                    if (stampImg != null) ...[
                      pw.SizedBox(height: 24),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Container(
                          width: 100,
                          height: 100,
                          child: pw.Image(stampImg),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    return DateFormat('dd/MM/yyyy').format(d);
  }

  String _numberToWords(int number) {
    if (number == 0) return 'ZERO';
    if (number < 0) return 'MINUS ${_numberToWords(number.abs())}';

    const units = [
      '',
      'ONE',
      'TWO',
      'THREE',
      'FOUR',
      'FIVE',
      'SIX',
      'SEVEN',
      'EIGHT',
      'NINE',
      'TEN',
      'ELEVEN',
      'TWELVE',
      'THIRTEEN',
      'FOURTEEN',
      'FIFTEEN',
      'SIXTEEN',
      'SEVENTEEN',
      'EIGHTEEN',
      'NINETEEN',
    ];
    const tens = [
      '',
      '',
      'TWENTY',
      'THIRTY',
      'FORTY',
      'FIFTY',
      'SIXTY',
      'SEVENTY',
      'EIGHTY',
      'NINETY',
    ];

    String convertHundreds(int n) {
      String s = '';
      if (n >= 100) {
        s += '${units[n ~/ 100]} HUNDRED';
        n = n % 100;
        if (n > 0) s += ' ';
      }
      if (n >= 20) {
        s += tens[n ~/ 10];
        if (n % 10 != 0) s += ' ${units[n % 10]}';
      } else if (n > 0) {
        s += units[n];
      }
      return s;
    }

    int crore = number ~/ 10000000;
    number %= 10000000;
    int lakh = number ~/ 100000;
    number %= 100000;
    int thousand = number ~/ 1000;
    number %= 1000;
    int hundred = number;

    final parts = <String>[];
    if (crore > 0) parts.add('${convertHundreds(crore)} CRORE');
    if (lakh > 0) parts.add('${convertHundreds(lakh)} LAKH');
    if (thousand > 0) parts.add('${convertHundreds(thousand)} THOUSAND');
    if (hundred > 0) parts.add(convertHundreds(hundred));

    return parts.join(' ');
  }

  Future<void> _handleDownloadAndUpload() async {
    try {
      setState(() => _isUploading = true);
      final bytes = await _buildPdfBytes();
      final fname = 'invoice_${DateTime.now().millisecondsSinceEpoch}.pdf';
      // 1) Create invoice record in backend
      final session = context.read<SessionProvider>();
      final agentId = session.agentId ?? 'MOBILE';
      final createdBy = session.agentName ?? 'mobile';

      final subtotal = _items.fold<double>(0.0, (s, e) => s + e.amount);
      final cgst = _withGst ? subtotal * 0.09 : 0.0;
      final sgst = _withGst ? subtotal * 0.09 : 0.0;
      final taxAmount = cgst + sgst;
      const double shipping = 0.0;
      final total = subtotal + taxAmount + shipping;

      final payload = <String, dynamic>{
        'agentId': agentId,
        'createdBy': createdBy,
        'customerId': null,
        'customerSnapshotJson': null,

        'companyName': _billedByName.text.trim(),
        'companyAddress': _billedByAddress.text.trim(),
        'companyGst': _billedByGstin.text.trim(),
        'companyMobile': _billedByMobile.text.trim(),
        'companyEmail': _billedByEmail.text.trim(),

        'customerAddress': _billedToAddress.text.trim(),
        'customerGst': _billedToGstin.text.trim(),
        'customerMobile': _billedToMobile.text.trim(),
        'customerEmail': _billedToEmail.text.trim(),

        'items': _items
            .map((i) => {
                  'productId': null,
                  'name': i.name,
                  'sku': null,
                  'unitPrice': i.rate,
                  'quantity': i.qty,
                  'discount': 0,
                  'tax': 0,
                  'lineTotal': i.amount,
                })
            .toList(),
        'subtotal': subtotal,
        'totalDiscount': 0,
        'taxAmount': taxAmount,
        'shipping': shipping,
        'total': total,
        'currency': 'INR',
        'status': 'DRAFT',
        'notes': _termsCtrl.text.trim(),

        'bankName': _bankName.text.trim(),
        'bankAccountNumber': _accountNumber.text.trim(),
        'bankHolderName': _accountName.text.trim(),
        'ifscCode': _ifscCode.text.trim(),
        'accountType': _accountType.text.trim(),
        'upiId': _upiId.text.trim(),

        'termsAndConditions': _termsCtrl.text.trim(),
        'paymentTerms': null,

        'companyLogoUrl': null,
        'companyStampUrl': null,
        'invoicePdfUrl': null,

        'invoiceDate': DateTime.now().toUtc().toIso8601String(),
        'dueDate': _dueDate?.toUtc().toIso8601String(),
      };

      final created = await ApiClient().createInvoice(payload);
      final invoiceId = created['id']?.toString();

      if (invoiceId == null) {
        throw Exception('Failed to create invoice');
      }

      // 2) Upload PDF to backend for this invoice
      await _uploadPdf(invoiceId, bytes, fileName: fname);

      final savedPath = await FileSaver.instance.saveFile(
        name: fname,
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (savedPath.isNotEmpty) {
        OpenFile.open(savedPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF uploaded and saved'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF uploaded'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload or save PDF'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadPdf(String invoiceId, Uint8List data,
      {required String fileName}) async {
    final uri = Uri.parse(
      'http://192.168.1.131:8080/api/v1/invoices/$invoiceId/pdf',
    );

    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        data,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      ),
    );

    final resp = await request.send();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Upload failed: ${resp.statusCode}');
    }
  }
}

class _InvoiceItem {
  final String name;
  final int qty;
  final double rate;
  _InvoiceItem({required this.name, required this.qty, required this.rate});
  double get amount => qty * rate;
}
