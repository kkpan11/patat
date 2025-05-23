--------------------------------------------------------------------------------
-- | Displaying code blocks, optionally with syntax highlighting.
{-# LANGUAGE BangPatterns      #-}
{-# LANGUAGE OverloadedStrings #-}
module Patat.Presentation.Display.CodeBlock
    ( prettyCodeBlock
    ) where


--------------------------------------------------------------------------------
import           Data.CaseInsensitive                (CI)
import qualified Data.CaseInsensitive                as CI
import           Data.Char.WCWidth.Extended          (wcstrwidth, wcwidth)
import           Data.Maybe                          (mapMaybe)
import qualified Data.Text                           as T
import           Patat.Presentation.Display.Internal
import qualified Patat.PrettyPrint                   as PP
import           Patat.Theme
import           Prelude
import qualified Skylighting                         as Skylighting


--------------------------------------------------------------------------------
highlight
    :: Skylighting.SyntaxMap -> [CI T.Text] -> T.Text
    -> [Skylighting.SourceLine]
highlight extraSyntaxMap classes rawCodeBlock =
    case mapMaybe getSyntax classes of
        []        -> zeroHighlight rawCodeBlock
        (syn : _) ->
            case Skylighting.tokenize config syn rawCodeBlock of
                Left  _  -> zeroHighlight rawCodeBlock
                Right sl -> sl
  where
    -- Note that SyntaxMap always uses lowercase keys.
    getSyntax :: CI T.Text -> Maybe Skylighting.Syntax
    getSyntax c = Skylighting.lookupSyntax (T.toLower $ CI.original c) syntaxMap

    config :: Skylighting.TokenizerConfig
    config = Skylighting.TokenizerConfig
        { Skylighting.syntaxMap  = syntaxMap
        , Skylighting.traceOutput = False
        }

    syntaxMap :: Skylighting.SyntaxMap
    syntaxMap = extraSyntaxMap <> Skylighting.defaultSyntaxMap


--------------------------------------------------------------------------------
-- | This does fake highlighting, everything becomes a normal token.  That makes
-- things a bit easier, since we only need to deal with one cases in the
-- renderer.
zeroHighlight :: T.Text -> [Skylighting.SourceLine]
zeroHighlight txt =
    [[(Skylighting.NormalTok, line)] | line <- T.lines txt]


--------------------------------------------------------------------------------
-- | Expands tabs in code lines.
expandTabs :: Int -> Skylighting.SourceLine -> Skylighting.SourceLine
expandTabs tabStop = goTokens 0
  where
    goTokens _    []                        = []
    goTokens col0 ((tokType, txt) : tokens) = goString col0 "" (T.unpack txt) $
        \col1 str -> (tokType, T.pack str) : goTokens col1 tokens

    goString :: Int -> String -> String -> (Int -> String -> k) -> k
    goString !col acc str k = case str of
        []       -> k col (reverse acc)
        '\t' : t -> goString (col + spaces) (replicate spaces ' ' ++ acc) t k
        c    : t -> goString (col + wcwidth c) (c : acc) t k
      where
        spaces = tabStop - col `mod` tabStop


--------------------------------------------------------------------------------
prettyCodeBlock :: DisplaySettings -> [CI T.Text] -> T.Text -> PP.Doc
prettyCodeBlock ds classes rawCodeBlock =
    PP.vcat (map blockified sourceLines) <> PP.hardline
  where
    sourceLines :: [Skylighting.SourceLine]
    sourceLines = map (expandTabs (dsTabStop ds)) $
        [[]] ++ highlight (dsSyntaxMap ds) classes rawCodeBlock ++ [[]]

    prettySourceLine :: Skylighting.SourceLine -> PP.Doc
    prettySourceLine = mconcat . map prettyToken

    prettyToken :: Skylighting.Token -> PP.Doc
    prettyToken (tokenType, str) = themed
        ds
        (\theme -> syntaxHighlight theme tokenType)
        (PP.text str)

    sourceLineLength :: Skylighting.SourceLine -> Int
    sourceLineLength line =
        sum [wcstrwidth (T.unpack str) | (_, str) <- line]

    blockWidth :: Int
    blockWidth = foldr max 0 (map sourceLineLength sourceLines)

    blockified :: Skylighting.SourceLine -> PP.Doc
    blockified line =
        let len    = sourceLineLength line
            indent = PP.Indentation 3 mempty in
        PP.indent indent indent $
        themed ds themeCodeBlock $
            " " <>
            prettySourceLine line <>
            PP.string (replicate (blockWidth - len) ' ') <> " "
