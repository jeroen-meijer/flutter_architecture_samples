// Copyright 2018 The Flutter Architecture Sample Authors. All rights reserved.
// Use of this source code is governed by the MIT license that can be found
// in the LICENSE file.

import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:todos_repository_core/todos_repository_core.dart';
import 'package:todos_repository_simple/todos_repository_simple.dart';

/// We create two Mocks for our web client and File Storage. We will use these
/// mock classes to verify the behavior of the TodosRepository.
class MockFileStorage extends Mock implements FileStorage {}

class MockWebClient extends Mock implements WebClient {}

class FakeFile extends Fake implements File {}

main() {
  group('TodosRepository', () {
    late FileStorage fileStorage;
    late WebClient webClient;

    const todos = [TodoEntity("Task", "1", "Hallo", false)];

    setUp(() {
      fileStorage = MockFileStorage();
      webClient = MockWebClient();

      when(() => fileStorage.saveTodos(any()))
          .thenAnswer((_) async => FakeFile());
    });

    test(
      'loads todos from file storage if they exist '
      'without calling the web client',
      () {
        final repository = TodosRepositoryFlutter(
          fileStorage: fileStorage,
          webClient: webClient,
        );

        // We'll use our mock throughout the tests to set certain conditions. In
        // this first test, we want to mock out our file storage to return a
        // list of Todos that we define here in our test!
        when(() => fileStorage.loadTodos()).thenAnswer((_) async => todos);

        expect(repository.loadTodos(), completion(todos));
        verifyNever(() => webClient.fetchTodos());
      },
    );

    test(
      'fetches todos from the web client if the file storage '
      'throws a synchronous error',
      () async {
        final repository = TodosRepositoryFlutter(
          fileStorage: fileStorage,
          webClient: webClient,
        );

        // In this instance, we'll ask our Mock to throw an error. When it does,
        // we expect the web client to be called instead.
        when(() => fileStorage.loadTodos()).thenThrow(Exception('oops'));
        when(() => webClient.fetchTodos()).thenAnswer((_) async => todos);

        // We check that the correct todos were returned, and that the
        // webClient.fetchTodos method was in fact called!
        await expectLater(
          repository.loadTodos(),
          completion(equals(todos)),
        );
        verify(() => webClient.fetchTodos()).called(1);
      },
    );

    test(
      'fetches todos from the web client if the file storage '
      'returns an async error',
      () async {
        final repository = TodosRepositoryFlutter(
          fileStorage: fileStorage,
          webClient: webClient,
        );

        when(() => fileStorage.loadTodos()).thenThrow(Exception('oops'));
        when(() => webClient.fetchTodos()).thenAnswer((_) async => todos);

        expect(
          repository.loadTodos(),
          completion(equals(todos)),
        );
        verify(() => webClient.fetchTodos()).called(1);
      },
    );

    test('persists the todos to local disk and the web client', () {
      final fileStorage = MockFileStorage();
      final webClient = MockWebClient();
      final repository = TodosRepositoryFlutter(
        fileStorage: fileStorage,
        webClient: webClient,
      );

      when(() => fileStorage.saveTodos(todos))
          .thenAnswer((_) async => File('falsch'));
      when(() => webClient.postTodos(todos)).thenAnswer((_) async => true);

      // In this case, we just want to verify we're correctly persisting to all
      // the storage mechanisms we care about.
      expect(repository.saveTodos(todos), completes);
      verify(() => fileStorage.saveTodos(todos)).called(1);
      verify(() => webClient.postTodos(todos)).called(1);
    });
  });
}
