# Logstash Plugin

This is a plugin for [Logstash](https://github.com/elastic/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Documentation

Logstash provides infrastructure to automatically generate documentation for this plugin. We use the asciidoc format to write documentation so any comments in the source code will be first converted into asciidoc and then into html. All plugin documentation are placed under one [central location](http://www.elastic.co/guide/en/logstash/current/).

However this is an extension of the http logsatsh plugin. Logsatsh http plugin does not support batching of requests and only makes per event requests. This have been modified here.

## Need Help?

Need help? Mail me at naveen.nitk2009@gmail.com or raise a bug in github repo issues page.

## Developing

### 1. Plugin Developement and Testing

#### Code
- To get started, you'll need JRuby with the Bundler gem installed.

- Create a new plugin or clone and existing from the GitHub [logstash-plugins](https://github.com/logstash-plugins) organization. We also provide [example plugins](https://github.com/logstash-plugins?query=example).

- Install dependencies
```sh
bundle install
```

#### Test

- Update your dependencies

```sh
bundle install
```

- Run tests
I am yet to write a test case for this. Basically I am going to extend the tests for http logsatsh plugin.

```sh
bundle exec rspec
```

### 2. Running your unpublished Plugin in Logstash

#### 2.1 Run in a local Logstash clone
- I am yet to host this plugin in gem repo.
- For now you will have to build this plugin locally and then install using logsatsh plugin utility.

- Build the plugin. This will need you to have complete plugin development environment setup locally. You can do this by visiting logstash plugin development page.
```
gem build logstash-output-httpbatch.gemspec
```

- Install the plugin.

```
bin/logsatsh-plugin install logstash-output-http-batch-X.Y.Z.gem
```

- Using the plugin in logstash output
Add this to output
```
output {
        httpbatch {
                http_method => 'post'
                url => 'http://myoutput.handler.url'
        }
}
```

### 3. Whats next ?
- Add tests
- Make a proper documentation. A lot of options from logsatsh http plugin is not supported here. Will list them down here.