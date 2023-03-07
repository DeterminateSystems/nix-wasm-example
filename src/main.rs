fn text_output() -> String {
    String::from("Hello from a Wasm program built using Nix and Rust!")
}

fn main() {
    println!("{}", text_output());
}

#[cfg(test)]
mod tests {
    use crate::text_output;

    #[test]
    fn text_output_matches_expected() {
        let output = text_output();
        assert_eq!(
            output,
            "Hello from a Wasm program built using Nix and Rust!"
        );
    }
}
