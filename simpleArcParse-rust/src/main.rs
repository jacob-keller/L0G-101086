use std::env;
use std::process;

mod parser;

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        panic!("Not enough command line arguments specified.");
    }

    let command = &args[1];

    let command = command
        .parse::<parser::Commands>()
        .expect("Invalid command type");

    println!("{:?}", command);
}
