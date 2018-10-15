use std::str::FromStr;

#[derive(PartialEq, Debug)]
pub enum Commands {
    Version,
    Header,
    Revision,
    Players,
    Success,
    StartTime,
}

impl FromStr for Commands {
    type Err = ();

    fn from_str(s: &str) -> Result<Commands, ()> {
        match s {
            "version" => Ok(Commands::Version),
            "header" => Ok(Commands::Header),
            "revision" => Ok(Commands::Revision),
            "players" => Ok(Commands::Players),
            "success" => Ok(Commands::Success),
            "start_time" => Ok(Commands::StartTime),
            _ => Err(()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn string_to_command() {
        let s = "version";
        assert_eq!(s.parse::<Commands>(), Ok(Commands::Version));

        let s = "header";
        assert_eq!(s.parse::<Commands>(), Ok(Commands::Header));
    }
}
