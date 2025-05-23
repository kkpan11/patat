-- | Read a presentation from disk.
{-# LANGUAGE BangPatterns      #-}
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
module Patat.Presentation.Read
    ( readPresentation

      -- Exposed for testing mostly.
    , detectSlideLevel
    , readMetaSettings
    ) where


--------------------------------------------------------------------------------
import           Control.Monad                   (guard)
import           Control.Monad.Except            (ExceptT (..), runExceptT,
                                                  throwError)
import           Control.Monad.Trans             (liftIO)
import qualified Data.Aeson.Extended             as A
import qualified Data.Aeson.KeyMap               as AKM
import           Data.Bifunctor                  (first)
import           Data.Maybe                      (fromMaybe)
import           Data.Sequence.Extended          (Seq)
import qualified Data.Sequence.Extended          as Seq
import qualified Data.Text                       as T
import qualified Data.Text.Encoding              as T
import           Data.Traversable                (for)
import qualified Data.Yaml                       as Yaml
import           Patat.EncodingFallback          (EncodingFallback)
import qualified Patat.EncodingFallback          as EncodingFallback
import qualified Patat.Eval                      as Eval
import           Patat.Presentation.Fragment
import           Patat.Presentation.Internal
import qualified Patat.Presentation.SpeakerNotes as SpeakerNotes
import           Patat.Presentation.Syntax
import           Patat.Transition                (parseTransitionSettings)
import           Patat.Unique
import           Prelude
import qualified Skylighting                     as Skylighting
import           System.Directory                (XdgDirectory (XdgConfig),
                                                  doesFileExist,
                                                  getHomeDirectory,
                                                  getXdgDirectory)
import           System.FilePath                 (splitFileName, takeExtension,
                                                  (</>))
import qualified Text.Pandoc.Error               as Pandoc
import qualified Text.Pandoc.Extended            as Pandoc


--------------------------------------------------------------------------------
readPresentation :: UniqueGen -> FilePath -> IO (Either String Presentation)
readPresentation uniqueGen filePath = runExceptT $ do
    -- We need to read the settings first.
    (enc, src)   <- liftIO $ EncodingFallback.readFile filePath
    homeSettings <- ExceptT readHomeSettings
    xdgSettings  <- ExceptT readXdgSettings
    metaSettings <- ExceptT $ return $ readMetaSettings src
    let settings =
            metaSettings <>
            xdgSettings  <>
            homeSettings <>
            defaultPresentationSettings

    syntaxMap <- ExceptT $ readSyntaxMap $ fromMaybe [] $
        psSyntaxDefinitions settings
    let pexts = fromMaybe defaultExtensionList (psPandocExtensions settings)
    reader <- case readExtension pexts ext of
        Nothing -> throwError $ "Unknown file extension: " ++ show ext
        Just x  -> return x
    doc <- case reader src of
        Left  e -> throwError $ "Could not parse document: " ++ show e
        Right x -> return x

    pres <- ExceptT $ pure $
        pandocToPresentation uniqueGen filePath enc settings syntaxMap doc
    pure $ fragmentPresentation $ Eval.parseEvalBlocks pres
  where
    ext = takeExtension filePath


--------------------------------------------------------------------------------
readSyntaxMap :: [FilePath] -> IO (Either String Skylighting.SyntaxMap)
readSyntaxMap =
    runExceptT .
    fmap (foldr Skylighting.addSyntaxDefinition mempty) .
    traverse (ExceptT . Skylighting.loadSyntaxFromFile)


--------------------------------------------------------------------------------
readExtension
    :: ExtensionList -> String
    -> Maybe (T.Text -> Either Pandoc.PandocError Pandoc.Pandoc)
readExtension (ExtensionList extensions) fileExt = case fileExt of
    ".markdown" -> Just $ Pandoc.runPure . Pandoc.readMarkdown readerOpts
    ".md"       -> Just $ Pandoc.runPure . Pandoc.readMarkdown readerOpts
    ".mdown"    -> Just $ Pandoc.runPure . Pandoc.readMarkdown readerOpts
    ".mdtext"   -> Just $ Pandoc.runPure . Pandoc.readMarkdown readerOpts
    ".mdtxt"    -> Just $ Pandoc.runPure . Pandoc.readMarkdown readerOpts
    ".mdwn"     -> Just $ Pandoc.runPure . Pandoc.readMarkdown readerOpts
    ".mkd"      -> Just $ Pandoc.runPure . Pandoc.readMarkdown readerOpts
    ".mkdn"     -> Just $ Pandoc.runPure . Pandoc.readMarkdown readerOpts
    ".lhs"      -> Just $ Pandoc.runPure . Pandoc.readMarkdown lhsOpts
    ""          -> Just $ Pandoc.runPure . Pandoc.readMarkdown readerOpts
    ".org"      -> Just $ Pandoc.runPure . Pandoc.readOrg      readerOpts
    ".txt"      -> Just $ pure . Pandoc.readPlainText
    _           -> Nothing

  where
    readerOpts = Pandoc.def
        { Pandoc.readerExtensions =
            extensions <> absolutelyRequiredExtensions
        }

    lhsOpts = readerOpts
        { Pandoc.readerExtensions =
            Pandoc.readerExtensions readerOpts <>
            Pandoc.extensionsFromList [Pandoc.Ext_literate_haskell]
        }

    absolutelyRequiredExtensions =
        Pandoc.extensionsFromList [Pandoc.Ext_yaml_metadata_block]


--------------------------------------------------------------------------------
pandocToPresentation
    :: UniqueGen -> FilePath -> EncodingFallback -> PresentationSettings
    -> Skylighting.SyntaxMap -> Pandoc.Pandoc -> Either String Presentation
pandocToPresentation pUniqueGen pFilePath pEncodingFallback pSettings pSyntaxMap
        pandoc@(Pandoc.Pandoc meta _) = do
    let !pTitle          = case Pandoc.docTitle meta of
            []    -> [Str . T.pack . snd $ splitFileName pFilePath]
            title -> fromPandocInlines title
        !pSlides         = pandocToSlides pSettings pandoc
        !pBreadcrumbs    = collectBreadcrumbs pSlides
        !pActiveFragment = (0, 0)
        !pAuthor         = fromPandocInlines $ concat $ Pandoc.docAuthors meta
        !pEvalBlocks     = mempty
        !pVars           = mempty
    pSlideSettings <- Seq.traverseWithIndex
        (\i slide -> case slideSettings slide of
            Left err  -> Left $ "on slide " ++ show (i + 1) ++ ": " ++ err
            Right cfg -> pure cfg)
        pSlides
    pTransitionGens <- for pSlideSettings $ \slideSettings ->
        case psTransition (slideSettings <> pSettings) of
            Nothing -> pure Nothing
            Just ts -> Just <$> parseTransitionSettings ts
    return $ Presentation {..}


--------------------------------------------------------------------------------
-- | This re-parses the pandoc metadata block using the YAML library.  This
-- avoids the problems caused by pandoc involving rendering Markdown.  This
-- should only be used for settings though, not things like title / authors
-- since those /can/ contain markdown.
parseMetadataBlock :: T.Text -> Maybe (Either String A.Value)
parseMetadataBlock src = case T.lines src of
    ("---" : ls) -> case break (`elem` ["---", "..."]) ls of
        (_,     [])      -> Nothing
        (block, (_ : _)) -> Just . first Yaml.prettyPrintParseException .
            Yaml.decodeEither' . T.encodeUtf8 . T.unlines $! block
    _            -> Nothing


--------------------------------------------------------------------------------
-- | Read settings from the metadata block in the Pandoc document.
readMetaSettings :: T.Text -> Either String PresentationSettings
readMetaSettings src = case parseMetadataBlock src of
    Nothing -> Right mempty
    Just (Left err) -> Left err
    Just (Right (A.Object obj)) | Just val <- AKM.lookup "patat" obj ->
       first (\err -> "Error parsing patat settings from metadata: " ++ err) $!
       A.resultToEither $! A.fromJSON val
    Just (Right _) -> Right mempty


--------------------------------------------------------------------------------
-- | Read settings from "$HOME/.patat.yaml".
readHomeSettings :: IO (Either String PresentationSettings)
readHomeSettings = do
    home <- getHomeDirectory
    readSettings $ home </> ".patat.yaml"


--------------------------------------------------------------------------------
-- | Read settings from "$XDG_CONFIG_DIRECTORY/patat/config.yaml".
readXdgSettings :: IO (Either String PresentationSettings)
readXdgSettings =
    getXdgDirectory XdgConfig ("patat" </> "config.yaml") >>= readSettings


--------------------------------------------------------------------------------
-- | Read settings from the specified path, if it exists.
readSettings :: FilePath -> IO (Either String PresentationSettings)
readSettings path = do
    exists <- doesFileExist path
    if not exists
        then return (Right mempty)
        else do
            errOrPs <- Yaml.decodeFileEither path
            return $! case errOrPs of
                Left  err -> Left (show err)
                Right ps  -> Right ps


--------------------------------------------------------------------------------
pandocToSlides :: PresentationSettings -> Pandoc.Pandoc -> Seq.Seq Slide
pandocToSlides settings (Pandoc.Pandoc _meta pblocks) =
    let blocks       = fromPandocBlocks pblocks
        slideLevel   = fromMaybe (detectSlideLevel blocks) (psSlideLevel settings)
        unfragmented = splitSlides slideLevel blocks in
    Seq.fromList unfragmented


--------------------------------------------------------------------------------
-- | Find level of header that starts slides.  This is defined as the least
-- header that occurs before a non-header in the blocks.
detectSlideLevel :: [Block] -> Int
detectSlideLevel blocks0 =
    go 6 $ filter (not . isComment) blocks0
  where
    go level (Header n _ _ : x : xs)
        | n < level && not (isHeader x) = go n xs
        | otherwise                     = go level (x:xs)
    go level (_ : xs)                   = go level xs
    go level []                         = level

    isHeader (Header _ _ _) = True
    isHeader _              = False


--------------------------------------------------------------------------------
-- | Split a pandoc document into slides.  If the document contains horizonal
-- rules, we use those as slide delimiters.  If there are no horizontal rules,
-- we split using headers, determined by the slide level (see
-- 'detectSlideLevel').
splitSlides :: Int -> [Block] -> [Slide]
splitSlides slideLevel blocks0
    | any isHorizontalRule blocks0 = splitAtRules   blocks0
    | otherwise                    = splitAtHeaders [] blocks0
  where
    mkContentSlide :: [Block] -> [Slide]
    mkContentSlide bs0 = do
        let bs1  = filter (not . isComment) bs0
            sns  = SpeakerNotes.SpeakerNotes [s | SpeakerNote s <- bs0]
            cfgs = concatCfgs [cfg | Config cfg <- bs0]
        guard $ not $ null bs1  -- Never create empty slides
        pure $ Slide sns cfgs $ ContentSlide bs1

    splitAtRules blocks = case break isHorizontalRule blocks of
        (xs, [])           -> mkContentSlide xs
        (xs, (_rule : ys)) -> mkContentSlide xs ++ splitAtRules ys

    splitAtHeaders acc [] =
        mkContentSlide (reverse acc)
    splitAtHeaders acc (b@(Header i _ txt) : bs0)
        | i > slideLevel  = splitAtHeaders (b : acc) bs0
        | i == slideLevel =
            mkContentSlide (reverse acc) ++ splitAtHeaders [b] bs0
        | otherwise       =
            let (cmnts, bs1) = break (not . isComment) bs0
                sns  = SpeakerNotes.SpeakerNotes [s | SpeakerNote s <- cmnts]
                cfgs = concatCfgs [cfg | Config cfg <- cmnts] in
            mkContentSlide (reverse acc) ++
            [Slide sns cfgs $ TitleSlide i txt] ++
            splitAtHeaders [] bs1
    splitAtHeaders acc (b : bs) =
        splitAtHeaders (b : acc) bs

    concatCfgs
        :: [Either String PresentationSettings]
        -> Either String PresentationSettings
    concatCfgs = fmap mconcat . sequence


--------------------------------------------------------------------------------
collectBreadcrumbs :: Seq Slide -> Seq Breadcrumbs
collectBreadcrumbs = go [] . fmap slideContent
  where
    go breadcrumbs slides0 = case Seq.viewl slides0 of
        Seq.EmptyL -> Seq.empty
        ContentSlide _ Seq.:< slides ->
            breadcrumbs `Seq.cons` go breadcrumbs slides
        TitleSlide lvl inlines Seq.:< slides ->
            let parent = filter ((< lvl) . fst) breadcrumbs in
            parent `Seq.cons` go (parent ++ [(lvl, inlines)]) slides
