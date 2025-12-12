import 'dart:io';
// ESTA IMPORTACIÓN FALTABA:
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class BackupRestoreService {
  final String dbFileName = 'investment_db.db';

  // ---------------- EXPORTAR (BACKUP) ----------------
  Future<String?> exportDatabase() async {
    try {
      // 1. Obtener la ruta de la base de datos actual
      final dbPath = await getDatabasesPath();
      final currentDbPath = join(dbPath, dbFileName);
      final sourceFile = File(currentDbPath);

      if (!await sourceFile.exists()) {
        return "Error: Archivo DB fuente no encontrado.";
      }

      // 2. Definir carpeta de destino (CORREGIDO)
      Directory? externalDir;

      if (Platform.isAndroid) {
        // En Android moderno, guardamos directo en la carpeta pública "Download"
        // para no necesitar permisos especiales.
        externalDir = Directory('/storage/emulated/0/Download');

        // Pequeña validación por si el teléfono usa "Downloads" (plural)
        if (!await externalDir.exists()) {
          externalDir = Directory('/storage/emulated/0/Downloads');
        }
      } else {
        // En iOS usamos la carpeta de documentos de la app
        externalDir = await getApplicationDocumentsDirectory();
      }

      // 3. Crear nombre de archivo con fecha
      final timestamp = DateTime.now()
          .toIso8601String()
          .substring(0, 16)
          .replaceAll(':', '-');

      final backupFileName = 'invest_tracker_$timestamp.db';

      // Ahora usamos externalDir.path con seguridad (o usamos ! porque ya validamos)
      final backupPath = join(externalDir.path, backupFileName);
      final destinationFile = File(backupPath);

      // Aseguramos que el directorio exista (útil en iOS)
      if (!await destinationFile.parent.exists()) {
        await destinationFile.parent.create(recursive: true);
      }

      // 4. Copiar el archivo
      await sourceFile.copy(destinationFile.path);

      return destinationFile.path;
    } catch (e) {
      debugPrint("Error al exportar el backup: $e");
      return "Error: Fallo durante la exportación ($e)";
    }
  }

  // ---------------- IMPORTAR (RESTAURAR) ----------------
  // ---------------- IMPORTAR (RESTAURAR) CORREGIDO ----------------
  Future<String?> importDatabase({
    required Future<void> Function() onDbReplaced,
    required Future<void> Function() onDbLoad,
  }) async {
    try {
      // 1. Elegir archivo
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result == null || result.files.single.path == null) {
        return "Selección cancelada.";
      }

      final selectedPath = result.files.single.path!;
      final importedFile = File(selectedPath);

      // 2. Cerrar la conexión actual
      await onDbReplaced();

      // 3. Obtener rutas
      final dbFolder = await getDatabasesPath();
      final dbPath = join(dbFolder, dbFileName);

      // 4. LIMPIEZA PROFUNDA (Borrar .db, .wal y .shm)
      // Si dejamos archivos basura (-wal), la nueva DB se corrompe al iniciar.
      final dbFile = File(dbPath);
      final walFile = File('$dbPath-wal'); // Archivo temporal Write-Ahead Log
      final shmFile = File('$dbPath-shm'); // Archivo temporal Shared Memory

      if (await dbFile.exists()) await dbFile.delete();
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      // 5. Copiar la nueva base de datos
      await importedFile.copy(dbPath);

      // 6. Pequeña pausa para asegurar que el sistema de archivos terminó
      await Future.delayed(const Duration(milliseconds: 500));

      // 7. Reabrir
      await onDbLoad();

      return "Base de datos restaurada correctamente.";
    } catch (e) {
      debugPrint("Error crítico al importar: $e");
      // Intentar revivir la app reabriendo
      await onDbLoad();
      return "Error al importar: $e";
    }
  }
}
