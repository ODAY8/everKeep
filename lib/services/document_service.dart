import 'package:flutter/material.dart';
import '../models/document_item.dart';

abstract class DocumentService {
  Future<List<DocumentItem>> fetchDocuments();
  Future<DocumentItem> addDocument(DocumentItem document);
  Future<void> deleteDocument(String id);
}

class DocumentServiceImpl implements DocumentService {
  // Seed items representing existing app data
  final List<DocumentItem> _mockDatabase = [
    const DocumentItem(
      id: 'doc-1',
      title: 'Last Will and Testament.pdf',
      subtitle: 'Legal · Added 2 days ago',
      category: 'Legal',
      icon: Icons.description_outlined,
      isVerified: true,
    ),
    const DocumentItem(
      id: 'doc-2',
      title: 'Medical Power of Attorney.pdf',
      subtitle: 'Medical · Added 1 week ago',
      category: 'Medical',
      icon: Icons.description_outlined,
      isVerified: false,
    ),
    const DocumentItem(
      id: 'doc-3',
      title: 'Property Deed.jpg',
      subtitle: 'Legal · Added 2 weeks ago',
      category: 'Legal',
      icon: Icons.description_outlined,
      isVerified: true,
    ),
    const DocumentItem(
      id: 'doc-4',
      title: 'Bank Statements Q3.xlsx',
      subtitle: 'Financial · Added 1 month ago',
      category: 'Financial',
      icon: Icons.description_outlined,
      isVerified: true,
    ),
  ];

  // TODO: Connect to real cloud document storage (e.g. S3 / Firebase Storage)

  @override
  Future<List<DocumentItem>> fetchDocuments() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List.from(_mockDatabase);
  }

  @override
  Future<DocumentItem> addDocument(DocumentItem document) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockDatabase.insert(0, document);
    return document;
  }

  @override
  Future<void> deleteDocument(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockDatabase.removeWhere((doc) => doc.id == id);
  }
}
