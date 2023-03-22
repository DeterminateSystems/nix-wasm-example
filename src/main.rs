use std::{env, process::exit};

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("ERROR");
        exit(1);
    }

    let name = &args[1];

    println!("Hello there, {name}!");
}
