workflow example {
  call hello
}

task hello {
  String who

  runtime {
    docker: "ubuntu"
  }

  command {
    echo 'Hello, ${who}!'
  }

  output {
    String out = read_string(stdout())
  }
}
