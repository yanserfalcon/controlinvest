import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class BackupRestoreService {
  final String dbFileName = 'investment_db.db';

  // ---------------- EXPORTAR (BACKUP) ----------------
  Future<String?> exportDatabase() async {
    try {
      // 1. Obtener la ruta de la base de datos actual (zona privada)
      final dbPath = await getDatabasesPath();
      final currentDbPath = join(dbPath, dbFileName);
      final sourceFile = File(currentDbPath);

      if (!await sourceFile.exists()) {
        return "Error: Archivo DB fuente no encontrado.";
      }

      // 2. Obtener la ruta de destino (carpeta pública de Descargas)
      // Se utiliza getExternalStorageDirectory() que es más robusto en Android
      //final Directory? externalDir = await getExternalStorageDirectory();
      final Directory externalDir = await getApplicationDocumentsDirectory();

      // 3. Crear nombre de archivo con timestamp
      final timestamp = DateTime.now()
          .toIso8601String()
          .substring(0, 16)
          .replaceAll(':', '-');
      final backupFileName = 'investment_tracker_backup_$timestamp.db';
      // La ruta será algo como: .../Android/data/com.tuapp/files/Download/archivo.db
      final backupPath = join(externalDir.path, 'Download', backupFileName);
      final destinationFile = File(backupPath);

      // Asegurar que el directorio de descarga exista
      await Directory(dirname(backupPath)).create(recursive: true);

      // 4. Copiar el archivo
      await sourceFile.copy(destinationFile.path);

      return destinationFile.path;
    } catch (e) {
      debugPrint("Error al exportar el backup: $e");
      return "Error: Fallo durante la exportación ($e)";
    }
  }

  // ---------------- IMPORTAR (RESTAURAR) ----------------
  Future<String?> importDatabase({
    // Callback para cerrar la DB antes de copiar
    required Future<void> Function() onDbReplaced,
    // Callback para reabrir la DB y recargar datos después de copiar
    required Future<void> Function() onDbLoad,
  }) async {
    try {
      // 1. Abrir selector de archivos
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'], // Solo archivos con extensión .db
      );

      if (result == null || result.files.single.path == null) {
        return "Selección de archivo cancelada.";
      }

      final selectedFilePath = result.files.single.path!;

      // 2. Cerrar la base de datos actual (CRÍTICO)
      await onDbReplaced();

      // 3. Obtener la ruta de la base de datos destino (zona privada)
      final dbPath = await getDatabasesPath();
      final targetDbPath = join(dbPath, dbFileName);

      // Asegurar que el directorio exista
      await Directory(dbPath).create(recursive: true);

      // 4. Copiar el archivo seleccionado sobre el archivo de la base de datos
      final importedFile = File(selectedFilePath);
      await importedFile.copy(targetDbPath);

      // 5. Reabrir la base de datos y forzar la recarga de transacciones
      await onDbLoad();

      return "Base de datos importada y restaurada con éxito.";
    } catch (e) {
      debugPrint("Error al importar el backup: $e");
      // Reabrir la base de datos en caso de error para evitar un estado roto
      await onDbLoad();
      return "Error: Fallo al importar la base de datos. Asegúrate de que el archivo es válido.";
    }
  }
}
