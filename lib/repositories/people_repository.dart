import '../models/person_item.dart';
import '../services/people_service.dart';

abstract class PeopleRepository {
  Future<List<PersonItem>> fetchPeople();
  Future<PersonItem> createPerson(String name);
  Future<PersonItem> updatePerson(String id, String newName);
  Future<void> deletePerson(String id);
  Future<List<PersonItem>> fetchPeopleForMemory(String memoryId);
  Future<void> setMemoryPeople(String memoryId, List<String> personIds);
}

class PeopleRepositoryImpl implements PeopleRepository {
  final PeopleService _peopleService;

  PeopleRepositoryImpl({PeopleService? peopleService})
      : _peopleService = peopleService ?? PeopleServiceImpl();

  @override
  Future<List<PersonItem>> fetchPeople() => _peopleService.fetchPeople();

  @override
  Future<PersonItem> createPerson(String name) =>
      _peopleService.createPerson(name);

  @override
  Future<PersonItem> updatePerson(String id, String newName) =>
      _peopleService.updatePerson(id, newName);

  @override
  Future<void> deletePerson(String id) => _peopleService.deletePerson(id);

  @override
  Future<List<PersonItem>> fetchPeopleForMemory(String memoryId) =>
      _peopleService.fetchPeopleForMemory(memoryId);

  @override
  Future<void> setMemoryPeople(String memoryId, List<String> personIds) =>
      _peopleService.setMemoryPeople(memoryId, personIds);
}
