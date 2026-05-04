import '../../../core/result/result.dart';
import 'models/ebook.dart';

abstract class ReaderRepository {
  Future<Result<Ebook>> openEpub(String path);
}
