import '../../../core/result/result.dart';
import '../../../core/models/ebook.dart';

abstract class ReaderRepository {
  Future<Result<Ebook>> openEpub(String path);
}
