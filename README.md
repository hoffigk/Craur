# Craur

* Version: 1.5-dev
* Date: Not yet released
* Build Status: [![Build Status](https://secure.travis-ci.org/DracoBlue/Craur.png?branch=master)](http://travis-ci.org/DracoBlue/Craur), 100% Code Coverage

The library craur has two main purposes:

1. Make writing Xml/Json Importers very convenient (query for multiple elements or exactly one element)
2. Implement a convention to convert XML to JSON without loosing any information

## What is wrong with vanilla JSON?

There is nothing wrong with JSON. But take this example:

    item = {
        "link": "http://example.org"
    }

If you want to query for the link, you do: `item.link`. But what if there can be multiple links? Like this:

    item = {
        "link": ["http://example.org", "http://subdomain.example.org"]
    }

Now you have to use `item.link[0]` to query for the first one. If you are converting xml programmaticly to json, you cannot be sure what is meant.

With craur querying for this value looks like this:

    $craur_node->get('item.link') // gets: "http://example.org"

And if you want to have an array, you do it like this:

    $craur_node->get('item.link[]') // gets: ["http://example.org", "http://subdomain.example.org"]

For craur it does not matter if you have an array or a simple object. Both calls will work.

You may even define a default value, in case the property is optional:

    $craur_node->get('item.description', 'Default Text!') // returns 'Default Text!'

## Example in PHP

This example is how it looks like if you parse a simple atom-feed with craur.

    $craur_node = Craur::createFromXml($xml_string);
    var_dump($craur_node->get('feed.@xmlns')); // http://www.w3.org/2005/Atom
    foreach ($craur_node->get('feed.entry.link[]') as $link) {
        var_dump($link->get('@href'));
    }

If you want to see more examples, please checkout the `php/tests/` folder. It contains a lot of examples.

## Tests

You can run the tests with:

    make test

The tests are located at `php/tests/`. The tests require `xdebug` to be installed and activated. A
successful test must have 100% code coverage.

### Constant/Continuous Testing

If you have `inotifywait` [linux, apt-get install inotify-tools] or `wait_on` [macosx, port install wait_on] installed, you can use:

    make test-constant

This will run the tests as soon as the files change. Very helpful if you want to do continuous testing.

## Api

### Craur::createFromJson(`$json_string`) : `Craur`

Will create and return a new craur instance for the given JSON string.

     $node = Craur::createFromJson('{"book": {"authors": ["Hans", "Paul"]}}');
     $authors = $node->get('book.authors[]');
     assert(count($authors) == 2);

### Craur::createFromXml(`$xml_string`) : `Craur`

Will create and return a new craur instance for the given XML string.

      $node = Craur::createFromXml('<book><author>Hans</author><author>Paul</author></book>');
      $authors = $node->get('book.author[]');
      assert(count($authors) == 2);

### Craur::createFromCsvFile(`$file_path, array $field_mappings`) : `Craur`

Will load the csv file and fill the objects according to the given `$field_mappings`.

    /*
     * If the file loooks like this:
     * Book Name;Book Year;Author Name
     * My Book;2012;Hans
     * My Book;2012;Paul
     * My second Book;2010;Erwin
     */
    $shelf = Craur::createFromCsvFile('fixtures/books.csv', array(
        'book[].name',
        'book[].year',
        'book[].author[].name',
    ));
    assert(count($shelf->get('book[]')) === 2);
    foreach ($shelf->get('book[]') as $book)
    {
        assert(in_array($book->get('name'), array('My Book', 'My second Book')));
        foreach ($book->get('author[]') as $author)
        {
            assert(in_array($author->get('name'), array('Hans', 'Paul', 'Erwin')));
        }
    }  

### Craur#get(`$path[, $default_value]`) : `Craur`|`mixed` 

Returns the value at a given path in the object. If the given path does not exist and an explicit `$default_value` is set: the `$default_value` will be returned. 

    $node = Craur::createFromJson('{"book": {"name": "MyBook", "authors": ["Hans", "Paul"]}}');
    
    $book = $node->get('book');
    assert($book->get('name') == 'MyBook');
    assert($book->get('price', 20) == 20);
    
    $authors = $node->get('book.authors[]');
    assert(count($authors) == 2);

### Craur#getWithFilter(`$path, $filter[, $default_value]`) : `Craur`|`mixed` 

Works similar to `Craur#get`, but can use a callable as filter object. Before returning the value, the function evaluates `$filter($value)` and returns this instead.

    $node = Craur::createFromJson('{"book": {"name": "MyBook", "authors": ["Hans", "Paul"]}}');
    
    $book = $node->get('book');
    assert($book->get('name') == 'MyBook');
    assert($book->get('price', 20) == 20);
    
    $authors = $node->get('book.authors[]');
    assert(count($authors) == 2);

The filter can also throw an exception to hide the value from the result set:
    
    function isACheapBook(Craur $value)
    {
        if ($value->get('price') > 20)
        {
            throw new Exception('Is no cheap book!');
        }
        return $value;
    }
    
    $node = Craur::createFromJson('{"books": [{"name":"A", "price": 30}, {"name": "B", "price": 10}, {"name": "C", "price": 15}]}');
    $cheap_books = $node->getWithFilter('books[]', 'isACheapBook');
    assert(count($cheap_books) == 2);
    assert($cheap_books[0]->get('name') == 'B');
    assert($cheap_books[1]->get('name') == 'C');

### Craur#getValues(`array $paths_map[, array $default_values, $default_value]`) : `mixed[]`

Return multiple values at once. If a given path is not set, one can use the `$default_values` array to specify a default. If a path is not set and no default value is given an exception will be thrown. If you want to have a default value, even if the path does not exist in `$default_values`, you can use `$default_value`.

    $node = Craur::createFromJson('{"book": {"name": "MyBook", "authors": ["Hans", "Paul"]}}');
    
    $values = $node->getValues(
        array(
            'name' => 'book.name',
            'book_price' => 'price',
            'first_author' => 'book.authors'
        ),
        array(
            'book_price' => 20
        )
    );
    
    assert($values['name'] == 'MyBook');
    assert($values['book_price'] == '20');
    assert($values['first_author'] == 'Hans');

### Craur#getValuesWithFilters(`array $paths_map, array $filters [, array $default_values, $default_value]`) : `mixed[]`

Works like `Craur#getValues`, but allows to set filters for each key in the `$path_map`.

    $node = Craur::createFromJson('{"book": {"name": "MyBook", "authors": ["Hans", "Paul"]}}');
    
    $values = $node->getValuesWithFilters(
        array(
            'name' => 'book.name',
            'book_price' => 'price',
            'first_author' => 'book.authors'
        ),
        array(
            'first_author' => 'strtoupper',
            'name' => 'strtolower'      
        ),
        array(
            'book_price' => 20
        )
    );
    
    assert($values['name'] == 'MyBook');
    assert($values['book_price'] == '20');
    assert($values['first_author'] == 'HANS');

### Craur#toJsonString() : `String`

Return the object as a json string. Can be loaded from `Craur::createFromJson`.

### Craur#toXmlString() : `String`

Return the object as a xml string. Can be loaded from `Craur::createFromXml`.

## Changelog

- 1.5-dev
  - fixed csv file test
  - only add csv values, which are not empty
  - added method to generate csv rows out of an object
- 1.4.1 (2012/03/14)
  - added `make test-constant` (watches for file changes with inotifywait on linux
    or wait_on on mac osx ) and runs tests on change
- 1.4.0 (2012/03/14)
  - added `Craur::createFromCsvFile($file_path, array $field_mappings)`
- 1.3.0 (2012/03/09)
  - added `getWithFilter($path, Callable $filter[, $default_value])`
  - added `getValuesWithFilters($path, array $filters[, array $default_values, $default_value])`
  - prepend the bootstrap file to all test files
  - ignore the test files themself in code coverage
- 1.2.0 (2012/03/06)
  - added extra `$default_value` optional parameter for Craur#getValues
  - added minimum code coverage for the tests to make a successful build
  - initialize the Craur also with just a plain php array
  - added summary for code coverage as text
  - added (disabled) experimental support for clover.xml code coverage files
- 1.1.0 (2012/03/06)
  - throw fatal error in case of failed assertion or an exception
  - throw error on invalid json
- 1.0.0 (2012/03/05)
  - added lots of phpdoc
  - Makefile uses ./run_tests.sh wrapper, to fail properly if one of the tests fails
  - it's now possible to retrieve a value of the first array element
  - Craur#get now also returns associative arrays as new Craur-objects, instead of failing
  - added bootstrap_for_test.php, so we can properly fail on warnings/assertions
  - added `Craur#getValues` to return multiple paths at once
  - split up the tests into separate files
  - added Makefile (do `make test` to execute tests)
  - added default_value for `Craur->get($path, $default_value)`
  - initial version 

## License

This work is copyright by DracoBlue (<http://dracoblue.net>) and licensed under the terms of MIT License.
