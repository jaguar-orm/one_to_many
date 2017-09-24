// Copyright (c) 2017, teja. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library one_to_many;

import 'dart:io';
import 'dart:async';
import 'package:jaguar_query/jaguar_query.dart';
import 'package:jaguar_orm/jaguar_orm.dart';
import 'package:jaguar_orm/src/relations/relations.dart';
import 'package:jaguar_query_postgresql/jaguar_query_postgresql.dart';

part 'main.g.dart';

class Author {
  @PrimaryKey()
  String id;

  String name;

  @HasMany(PostBean)
  List<Post> posts;

  static const String tableName = 'author';

  String toString() => "Author($id, $name, $posts)";
}

class Post {
  @PrimaryKey()
  String id;

  String message;

  @BelongsTo(AuthorBean)
  String authorid;

  static String tableName = 'post';

  String toString() => "Post($id, $authorid, $message)";
}

@GenBean()
class AuthorBean extends Bean<Author> with _AuthorBean {
  final PostBean postBean;

  AuthorBean(Adapter adapter)
      : postBean = new PostBean(adapter),
        super(adapter);

  Future createTable() {
    final st = Sql
        .create(tableName)
        .addStr('id', primary: true, length: 50)
        .addStr('name', length: 50);
    return execCreateTable(st);
  }
}

@GenBean()
class PostBean extends Bean<Post> with _PostBean {
  PostBean(Adapter adapter) : super(adapter);

  Future createTable() {
    final st = Sql
        .create(tableName)
        .addStr('id', primary: true, length: 50)
        .addStr('message', length: 150)
        .addStr('authorid',
            length: 50, foreignTable: Author.tableName, foreignCol: 'id');
    return execCreateTable(st);
  }
}

/// The adapter
PgAdapter _adapter =
    new PgAdapter('postgres://postgres:dart_jaguar@localhost/example');

main() async {
  // Connect to database
  await _adapter.connect();

  // Create beans
  final authorBean = new AuthorBean(_adapter);
  final postBean = new PostBean(_adapter);

  // Drop old tables
  await postBean.drop();
  await authorBean.drop();

  // Create new tables
  await authorBean.createTable();
  await postBean.createTable();

  // Cascaded One-To-One insert
  {
    final author = new Author()
      ..id = '1'
      ..name = 'Teja'
      ..posts = <Post>[
        new Post()
          ..id = '10'
          ..message = 'Message 10',
        new Post()
          ..id = '11'
          ..message = 'Message11'
      ];
    await authorBean.insert(author, cascade: true);
  }

  // Fetch One-To-One preloaded
  {
    final author = await authorBean.find('1', preload: true);
    print(author);
  }

  // Manual One-To-One insert
  {
    Author author = new Author()
      ..id = '2'
      ..name = 'Kleak';
    await authorBean.insert(author, cascade: true);

    author = await authorBean.find('2');

    final post1 = new Post()
      ..id = '20'
      ..message = 'Message 20';
    postBean.associateAuthor(post1, author);
    await postBean.insert(post1);

    final post2 = new Post()
      ..id = '21'
      ..message = 'Message 21';
    postBean.associateAuthor(post2, author);
    await postBean.insert(post2);
  }

  // Manual One-To-One preload
  {
    final author = await authorBean.find('2');
    print(author);
    author.posts = await postBean.findByAuthor(author.id);
    print(author);
  }

  // Preload many
  {
    final authors = await authorBean.getAll();
    print(authors);
    await authorBean.preloadAll(authors);
    print(authors);
  }

  // Cascaded One-To-One update
  {
    Author author = await authorBean.find('1', preload: true);
    author.name = 'Teja Hackborn';
    author.posts[0].message += '!';
    author.posts[1].message += '!';
    await authorBean.update(author, cascade: true);
  }

  // Fetch One-To-One relationship preloaded
  {
    final user = await authorBean.find('1', preload: true);
    print(user);
  }

  // Cascaded removal of One-To-One relation
  await authorBean.remove('1', true);

  // Preload many
  {
    final authors = await authorBean.getAll();
    print(authors);
    await authorBean.preloadAll(authors);
    print(authors);
  }
  print(await postBean.getAll());

  // Remove addresses belonging to a User
  await postBean.removeByAuthor('2');

  print(await postBean.getAll());

  exit(0);
}
